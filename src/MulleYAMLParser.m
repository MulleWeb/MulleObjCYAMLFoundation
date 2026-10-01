//
//  MulleYAMLParser.m
//  MulleObjCYAMLFoundation
//
//  Copyright (c) 2026 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#import "import-private.h"

// other files in this library
#import "MulleYAMLParser.h"

// std-c and dependencies
#include <mulle-allocator/mulle-alloca.h>
#include <yaml.h>

#include <ctype.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>


// every resolved YAML core tag starts with this
#define MULLE_YAML_TAG_PREFIX          "tag:yaml.org,2002:"
#define MULLE_YAML_TAG_PREFIX_LENGTH   (sizeof( MULLE_YAML_TAG_PREFIX) - 1)

#define MULLE_YAML_MERGE_TAG           "tag:yaml.org,2002:merge"


@interface MulleYAMLParser( Private)

- (id) objectFromNode:(yaml_node_t *) node
             document:(yaml_document_t *) document;

- (id) objectFromScalarNode:(yaml_node_t *) node;
- (id) objectFromSequenceNode:(yaml_node_t *) node
                     document:(yaml_document_t *) document;
- (id) objectFromMappingNode:(yaml_node_t *) node
                    document:(yaml_document_t *) document;

- (void) mulleSetProblem:(NSString *) problem
                    line:(NSUInteger) line
                  column:(NSUInteger) column;

@end


static BOOL   isMergeKeyNode( yaml_node_t *node)
{
   char   *tag;
   char   *value;

   if( node->type != YAML_SCALAR_NODE)
      return( NO);

   tag = (char *) node->tag;
   if( tag && strcmp( tag, YAML_STR_TAG))
      return( ! strcmp( tag, MULLE_YAML_MERGE_TAG));

   // libyaml replaces a missing tag with the string tag, so "<<" is
   // recognized by its text. A quoted "<<" is an ordinary key, hence the
   // style test.
   if( node->data.scalar.style != YAML_PLAIN_SCALAR_STYLE)
      return( NO);
   if( node->data.scalar.length != 2)
      return( NO);

   value = (char *) node->data.scalar.value;
   return( value[ 0] == '<' && value[ 1] == '<');
}


//
// libyaml resolves the tag of a plain scalar, but it does not convert the
// text: a node tagged !!int still carries "010". These helpers convert. They
// answer NO in *p_ok when the text is not something we want to hand out as a
// number, and the caller then falls back to a string. That is a visible wrong
// answer rather than a silently wrong one.
//
static long long   parseYAMLInteger( char *s, NSUInteger length, BOOL *p_ok)
{
   char        *end;
   long long   value;

   *p_ok = NO;
   value = 0;

   mulle_alloca_do( tmp, char, length + 1)
   {
      NSUInteger   i;
      NSUInteger   n;

      // YAML 1.1 allows _ as a digit separator, strtoll does not
      n = 0;
      for( i = 0; i < length; i++)
         if( s[ i] != '_')
            tmp[ n++] = s[ i];
      tmp[ n] = 0;

      end = NULL;
      // 0b is YAML 1.1, but not C
      if( n > 2 && tmp[ 0] == '0' && (tmp[ 1] == 'b' || tmp[ 1] == 'B'))
         value = strtoll( &tmp[ 2], &end, 2);
      else
         // base 0 covers 0x hex and leading 0 octal
         value = strtoll( tmp, &end, 0);

      if( end != tmp && end && ! *end)
         *p_ok = YES;
   }
   return( value);
}


// YAML 1.1 requires the '.' of a float, which is what keeps "08" a string.
// Without it strtod would read "08" as 8 and "1e5" as a float, and Psych
// would not.
static BOOL   isYAMLFloatText( char *s, NSUInteger length)
{
   NSUInteger   i;
   BOOL         digits;
   BOOL         dot;

   i      = 0;
   digits = NO;
   dot    = NO;

   if( i < length && (s[ i] == '+' || s[ i] == '-'))
      i++;

   // the integer part
   for( ; i < length && (isdigit( (unsigned char) s[ i]) || s[ i] == '_'); i++)
      if( s[ i] != '_')
         digits = YES;

   if( i < length && s[ i] == '.')
   {
      dot = YES;
      for( i++; i < length && (isdigit( (unsigned char) s[ i]) || s[ i] == '_'); i++)
         if( s[ i] != '_')
            digits = YES;
   }

   if( ! dot || ! digits)
      return( NO);

   // the exponent is optional, but it needs at least one digit
   if( i < length && (s[ i] == 'e' || s[ i] == 'E'))
   {
      i++;
      if( i < length && (s[ i] == '+' || s[ i] == '-'))
         i++;
      if( i >= length || ! isdigit( (unsigned char) s[ i]))
         return( NO);
      for( ; i < length && isdigit( (unsigned char) s[ i]); i++)
         ;
   }

   return( i == length);
}


static double   parseYAMLFloat( char *s, NSUInteger length, BOOL *p_ok)
{
   char         *end;
   NSUInteger   i;
   double       value;

   *p_ok = NO;
   value = 0.0;

   // .inf, -.inf, +.inf and .nan are the only float forms strtod can't do
   i = 0;
   if( i < length && (s[ i] == '+' || s[ i] == '-'))
      i++;

   if( i < length && s[ i] == '.')
   {
      if( length - i == 4 && ! strncmp( &s[ i], ".inf", 4))
      {
         *p_ok = YES;
         return( s[ 0] == '-' ? -HUGE_VAL : HUGE_VAL);
      }
      if( length - i == 4 && ! strncmp( &s[ i], ".nan", 4) && s[ 0] != '-')
      {
         *p_ok = YES;
         return( NAN);
      }
   }

   if( ! isYAMLFloatText( s, length))
      return( 0.0);

   mulle_alloca_do( tmp, char, length + 1)
   {
      NSUInteger   n;

      n = 0;
      for( i = 0; i < length; i++)
         if( s[ i] != '_')
            tmp[ n++] = s[ i];
      tmp[ n] = 0;

      end   = NULL;
      value = strtod( tmp, &end);
      if( end != tmp && end && ! *end)
         *p_ok = YES;
   }
   return( value);
}


//
// YAML 1.1 spells a word in three ways: "yes", "Yes" and "YES" - and
// nothing else. So this is not a case insensitive compare, which would make
// "yEs" a boolean.
//
static BOOL   matchesYAMLWord( char *s, NSUInteger length, char *word)
{
   NSUInteger   i;
   NSUInteger   n;
   BOOL         ok;

   n = strlen( word);
   if( n != length)
      return( NO);

   // "yes"
   if( ! strncmp( s, word, n))
      return( YES);

   // "YES"
   ok = YES;
   for( i = 0; i < n && ok; i++)
      ok = (s[ i] == (char) toupper( (unsigned char) word[ i]));
   if( ok)
      return( YES);

   // "Yes"
   if( s[ 0] == (char) toupper( (unsigned char) word[ 0]))
      if( ! strncmp( &s[ 1], &word[ 1], n - 1))
         return( YES);

   return( NO);
}


// YAML 1.1 booleans are y|Y|yes|Yes|YES|n|N|no|No|NO|true|True|TRUE|false|
// False|FALSE|on|On|ON|off|Off|OFF - so the first letter decides which word
// to compare against, and everything else stays a string
static BOOL   parseYAMLBoolean( char *s, NSUInteger length, BOOL *p_value)
{
   if( ! length)
      return( NO);

   switch( s[ 0])
   {
   case 'y' :
   case 'Y' :
      if( matchesYAMLWord( s, length, "y") || matchesYAMLWord( s, length, "yes"))
      {
         *p_value = YES;
         return( YES);
      }
      break;

   case 'n' :
   case 'N' :
      if( matchesYAMLWord( s, length, "n") || matchesYAMLWord( s, length, "no"))
      {
         *p_value = NO;
         return( YES);
      }
      break;

   case 't' :
   case 'T' :
      if( matchesYAMLWord( s, length, "true"))
      {
         *p_value = YES;
         return( YES);
      }
      break;

   case 'f' :
   case 'F' :
      if( matchesYAMLWord( s, length, "false"))
      {
         *p_value = NO;
         return( YES);
      }
      break;

   case 'o' :
   case 'O' :
      if( matchesYAMLWord( s, length, "on"))
      {
         *p_value = YES;
         return( YES);
      }
      if( matchesYAMLWord( s, length, "off"))
      {
         *p_value = NO;
         return( YES);
      }
      break;

   default :
      break;
   }
   return( NO);
}


// the null spellings are ~, null|Null|NULL and the empty scalar
static BOOL   isYAMLNullText( char *s, NSUInteger length)
{
   if( ! length)
      return( YES);
   if( length == 1 && s[ 0] == '~')
      return( YES);
   return( matchesYAMLWord( s, length, "null"));
}


//
// libyaml does not resolve implicit tags: a plain scalar arrives without any
// tag, so the YAML 1.1 core schema is applied here. This is the step that
// makes "yes" a boolean and "08" a string, the same way Ruby's Psych does it
// for Jekyll. A quoted or a block scalar never comes here.
//
static id   objectFromPlainScalar( char *s, NSUInteger length)
{
   long long   integer;
   double      value;
   BOOL        boolean;
   BOOL        ok;

   if( isYAMLNullText( s, length))
      return( [NSNull null]);

   if( parseYAMLBoolean( s, length, &boolean))
      return( [NSNumber numberWithBool:boolean]);

   integer = parseYAMLInteger( s, length, &ok);
   if( ok)
      return( [NSNumber numberWithLongLong:integer]);

   value = parseYAMLFloat( s, length, &ok);
   if( ok)
      return( [NSNumber numberWithDouble:value]);

   return( [NSString mulleStringWithUTF8Characters:s
                                            length:length]);
}


@implementation MulleYAMLParser

@method_implementation +parser = +instance;


- (void) dealloc
{
   [_problem release];
   [super dealloc];
}


- (void) mulleSetProblem:(NSString *) problem
                    line:(NSUInteger) line
                  column:(NSUInteger) column
{
   [_problem autorelease];
   _problem = [problem retain];
   _line    = line;
   _column  = column;

   [NSError mulleSetGenericErrorWithDomain:@"YAMLPlistDomain"
                      localizedDescription:problem];
}


- (id) objectFromScalarNode:(yaml_node_t *) node
{
   char        *tag;
   char        *value;
   BOOL        boolean;
   BOOL        ok;
   NSUInteger  length;

   value  = (char *) node->data.scalar.value;
   length = (NSUInteger) node->data.scalar.length;
   tag    = (char *) node->tag;

   if( ! tag)
      tag = (char *) YAML_STR_TAG;

   //
   // libyaml replaces a missing tag - and "!" - with the string tag, so a node
   // carrying it is either an implicit scalar or an explicit "!!str". The
   // style tells those apart in every case but a plain "!!str", where YAML
   // wants text and the core schema would convert. So only a plain scalar is
   // resolved, a quoted or block scalar stays text.
   //
   if( ! strcmp( tag, YAML_STR_TAG))
   {
      if( node->data.scalar.style == YAML_PLAIN_SCALAR_STYLE)
         return( objectFromPlainScalar( value, length));

      return( [NSString mulleStringWithUTF8Characters:value
                                               length:length]);
   }

   if( ! strncmp( tag, MULLE_YAML_TAG_PREFIX, MULLE_YAML_TAG_PREFIX_LENGTH))
   {
      tag += MULLE_YAML_TAG_PREFIX_LENGTH;

      if( ! strcmp( tag, "null"))
         return( [NSNull null]);

      if( ! strcmp( tag, "bool"))
      {
         if( parseYAMLBoolean( value, length, &boolean))
            return( [NSNumber numberWithBool:boolean]);
      }
      else
      {
         if( ! strcmp( tag, "int"))
         {
            long long   v;

            v = parseYAMLInteger( value, length, &ok);
            if( ok)
               return( [NSNumber numberWithLongLong:v]);
         }
         else
         {
            if( ! strcmp( tag, "float"))
            {
               double   v;

               v  = parseYAMLFloat( value, length, &ok);
               if( ok)
                  return( [NSNumber numberWithDouble:v]);
            }
         }
      }
   }

   // !!str, !!timestamp, !!binary, unknown tags and anything we could not
   // convert remain text
   return( [NSString mulleStringWithUTF8Characters:value
                                            length:length]);
}


- (BOOL) mergeValue:(id) value
     intoDictionary:(NSMutableDictionary *) dictionary
               line:(NSUInteger) line
             column:(NSUInteger) column
{
   NSArray     *sources;
   NSString    *problem;
   id          key;
   id          source;

   sources = [value isKindOfClass:[NSArray class]] ? (NSArray *) value : @[ value];

   for( source in sources)
   {
      if( ! [source isKindOfClass:[NSDictionary class]])
      {
         problem = [NSString stringWithFormat:@"line %lu, column %lu: a \"<<\" merge key needs a mapping or a sequence of mappings",
                              (unsigned long) line,
                              (unsigned long) column];
         [self mulleSetProblem:problem
                          line:line
                        column:column];
         return( NO);
      }

      for( key in source)
         // first mapping wins, and the mapping's own keys win over all
         if( ! [dictionary objectForKey:key])
            [dictionary setObject:[source objectForKey:key]
                           forKey:key];
   }
   return( YES);
}


- (id) objectFromSequenceNode:(yaml_node_t *) node
                     document:(yaml_document_t *) document
{
   NSMutableArray      *array;
   yaml_node_item_t    *item;
   yaml_node_t         *nodeItem;
   id                  value;

   array = [NSMutableArray array];
   for( item = node->data.sequence.items.start; item < node->data.sequence.items.top; item++)
   {
      nodeItem = yaml_document_get_node( document, *item);
      value    = [self objectFromNode:nodeItem
                             document:document];
      if( ! value)
         return( nil);

      [array addObject:value];
   }
   return( array);
}


- (id) objectFromMappingNode:(yaml_node_t *) node
                    document:(yaml_document_t *) document
{
   NSMutableDictionary   *dictionary;
   NSString              *problem;
   yaml_node_pair_t      *pair;
   yaml_node_t           *keyNode;
   yaml_node_t           *valueNode;
   id                    key;
   id                    value;

   dictionary = [NSMutableDictionary dictionary];

   // pass one is the "<<" merges, pass two the mapping's own keys, which win
   for( pair = node->data.mapping.pairs.start; pair < node->data.mapping.pairs.top; pair++)
   {
      keyNode = yaml_document_get_node( document, pair->key);
      if( ! isMergeKeyNode( keyNode))
         continue;

      valueNode = yaml_document_get_node( document, pair->value);
      value     = [self objectFromNode:valueNode
                             document:document];
      if( ! value)
         return( nil);

      if( ! [self mergeValue:value
              intoDictionary:dictionary
                        line:keyNode->start_mark.line + 1
                      column:keyNode->start_mark.column + 1])
         return( nil);
   }

   for( pair = node->data.mapping.pairs.start; pair < node->data.mapping.pairs.top; pair++)
   {
      keyNode = yaml_document_get_node( document, pair->key);
      if( isMergeKeyNode( keyNode))
         continue;

      key = [self objectFromNode:keyNode
                        document:document];
      if( ! key)
         return( nil);

      // a collection cannot be a dictionary key, null can (YAML allows it)
      if( ! [key isKindOfClass:[NSString class]]
          && ! [key isKindOfClass:[NSNumber class]]
          && ! [key isKindOfClass:[NSNull class]])
      {
         problem = [NSString stringWithFormat:@"line %lu, column %lu: mapping key is a collection",
                              (unsigned long) keyNode->start_mark.line + 1,
                              (unsigned long) keyNode->start_mark.column + 1];
         [self mulleSetProblem:problem
                          line:keyNode->start_mark.line + 1
                        column:keyNode->start_mark.column + 1];
         return( nil);
      }

      valueNode = yaml_document_get_node( document, pair->value);
      value     = [self objectFromNode:valueNode
                             document:document];
      if( ! value)
         return( nil);

      [dictionary setObject:value
                     forKey:key];
   }

   return( dictionary);
}


- (id) objectFromNode:(yaml_node_t *) node
             document:(yaml_document_t *) document
{
   switch( node->type)
   {
   case YAML_SCALAR_NODE   : return( [self objectFromScalarNode:node]);
   case YAML_SEQUENCE_NODE : return( [self objectFromSequenceNode:node
                                                          document:document]);
   case YAML_MAPPING_NODE  : return( [self objectFromMappingNode:node
                                                         document:document]);

   default : break;
   }
   return( nil);
}


- (id) emptyDocumentResult
{
   if( _nilOnEmptyDocument)
      return( nil);
   return( [NSDictionary dictionary]);
}


- (id) parseData:(NSData *) data
{
   yaml_document_t   document;
   yaml_node_t       *root;
   NSString          *problem;
   yaml_parser_t     parser;
   id                plist;

   [_problem autorelease];
   _problem = nil;
   _line    = 0;
   _column  = 0;

   if( ! [data length])
      return( [self emptyDocumentResult]);

   memset( &parser, 0, sizeof( parser));
   if( ! yaml_parser_initialize( &parser))
   {
      [self mulleSetProblem:@"could not initialize the YAML parser"
                       line:0
                     column:0];
      return( nil);
   }

   yaml_parser_set_input_string( &parser, [data bytes], [data length]);

   memset( &document, 0, sizeof( document));
   if( ! yaml_parser_load( &parser, &document))
   {
      problem = [NSString stringWithFormat:@"line %lu, column %lu: %s",
                           (unsigned long) parser.problem_mark.line + 1,
                           (unsigned long) parser.problem_mark.column + 1,
                           parser.problem ? parser.problem : "YAML error"];
      [self mulleSetProblem:problem
                       line:parser.problem_mark.line + 1
                     column:parser.problem_mark.column + 1];
      yaml_parser_delete( &parser);
      return( nil);
   }

   yaml_parser_delete( &parser);

   root = yaml_document_get_root_node( &document);
   if( ! root)
   {
      yaml_document_delete( &document);
      return( [self emptyDocumentResult]);
   }

   plist = [self objectFromNode:root
                       document:&document];
   yaml_document_delete( &document);
   return( plist);
}

@end


@implementation NSString( MulleYAMLParser)

- (id) mulleYAML
{
   return( [[MulleYAMLParser parser] parseData:[self dataUsingEncoding:NSUTF8StringEncoding]]);
}

@end
