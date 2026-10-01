//
//  MulleYAMLWriter.m
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
#import "MulleYAMLWriter.h"

// std-c and dependencies
#include <ctype.h>
#include <math.h>
#include <string.h>


//
// A scalar is written plain only if the reader would read it back as the
// same string. Everything else is double quoted, which is always safe. The
// classification below mirrors the YAML 1.1 core schema that the parser
// applies to plain scalars.
//

static BOOL   yamlWordMatches( char *s, NSUInteger length, char *word)
{
   NSUInteger   i;
   NSUInteger   n;
   BOOL         ok;

   n = strlen( word);
   if( n != length)
      return( NO);

   // "word"
   if( ! strncmp( s, word, n))
      return( YES);

   // "WORD"
   ok = YES;
   for( i = 0; i < n && ok; i++)
      ok = (s[ i] == (char) toupper( (unsigned char) word[ i]));
   if( ok)
      return( YES);

   // "Word"
   if( s[ 0] == (char) toupper( (unsigned char) word[ 0]))
      if( ! strncmp( &s[ 1], &word[ 1], n - 1))
         return( YES);

   return( NO);
}


static BOOL   yamlTextIsNull( char *s, NSUInteger length)
{
   if( ! length)
      return( YES);
   if( length == 1 && s[ 0] == '~')
      return( YES);
   return( yamlWordMatches( s, length, "null"));
}


static BOOL   yamlTextIsBoolean( char *s, NSUInteger length)
{
   static char   *words[] = { "y", "yes", "n", "no", "true", "false", "on", "off", NULL };
   int           i;

   for( i = 0; words[ i]; i++)
      if( yamlWordMatches( s, length, words[ i]))
         return( YES);
   return( NO);
}


static BOOL   yamlTextIsInteger( char *s, NSUInteger length)
{
   char        *p;
   char        *sentinel;
   NSUInteger   base;
   BOOL         digit;

   if( ! length)
      return( NO);

   p        = s;
   sentinel = &s[ length];

   if( *p == '+' || *p == '-')
      p++;

   if( p == sentinel)
      return( NO);

   base = 10;
   if( sentinel - p > 2 && p[ 0] == '0' && (p[ 1] == 'x' || p[ 1] == 'X'))
   {
      base = 16;
      p   += 2;
   }
   else
      if( sentinel - p > 2 && p[ 0] == '0' && (p[ 1] == 'b' || p[ 1] == 'B'))
      {
         base = 2;
         p   += 2;
      }

   digit = NO;
   for( ; p < sentinel; p++)
   {
      char   c;

      c = *p;
      if( c == '_')
         continue;

      if( base == 16 ? isxdigit( (unsigned char) c)
                     : (base == 2 ? (c == '0' || c == '1')
                                  : isdigit( (unsigned char) c)))
      {
         digit = YES;
         continue;
      }
      return( NO);
   }
   return( digit);
}


static BOOL   yamlTextIsFloat( char *s, NSUInteger length)
{
   NSUInteger   i;
   BOOL         digit;
   BOOL         dot;
   BOOL         exp;

   i = 0;
   if( i < length && (s[ i] == '+' || s[ i] == '-'))
      i++;

   // .inf and .nan are floats even without a digit
   if( i < length && s[ i] == '.')
      if( length - i == 4)
         if( ! strncmp( &s[ i], ".inf", 4) || ! strncmp( &s[ i], ".nan", 4))
            return( YES);

   digit = NO;
   dot   = NO;
   exp   = NO;

   for( ; i < length; i++)
   {
      char   c;

      c = s[ i];
      if( isdigit( (unsigned char) c))
      {
         digit = YES;
         continue;
      }
      if( c == '_')
         continue;
      if( c == '.' && ! dot && ! exp)
      {
         dot = YES;
         continue;
      }
      if( (c == 'e' || c == 'E') && ! exp)
      {
         exp = YES;
         if( i + 1 < length && (s[ i + 1] == '+' || s[ i + 1] == '-'))
            i++;
         continue;
      }
      return( NO);
   }

   return( digit && (dot || exp));
}


static BOOL   yamlTextIsCoreScalar( char *s, NSUInteger length)
{
   return( yamlTextIsNull( s, length)
           || yamlTextIsBoolean( s, length)
           || yamlTextIsInteger( s, length)
           || yamlTextIsFloat( s, length));
}


static BOOL   yamlStringCanBePlain( NSString *s)
{
   char         *c;
   NSUInteger   i;
   NSUInteger   length;

   c      = (char *) [s UTF8String];
   length = c ? strlen( c) : 0;
   if( ! length)
      return( NO);

   // non ASCII, control characters and anything structural is quoted
   for( i = 0; i < length; i++)
   {
      unsigned char   ch;

      ch = (unsigned char) c[ i];
      if( ch >= 0x80)
         return( NO);
      if( ch == ' ' || ch == '_' || ch == '-' || ch == '.' || ch == '/'
          || isalnum( ch))
         continue;
      return( NO);
   }

   // leading and trailing whitespace and indicator characters are unsafe
   if( c[ 0] == ' ' || c[ 0] == '-' || c[ 0] == '.')
      return( NO);
   if( c[ length - 1] == ' ')
      return( NO);

   if( yamlTextIsCoreScalar( c, length))
      return( NO);

   return( YES);
}


static NSString   *yamlDoubleQuotedString( NSString *s)
{
   NSMutableData   *out;
   unsigned char   ch;
   char            *c;
   char            escape[ 5 ];
   NSUInteger      i;
   NSUInteger      length;
   static char     hex[ 16] = "0123456789abcdef";

   // collect UTF8 bytes, so a multibyte character is not split into
   // invalid single byte strings
   out = [NSMutableData data];
   [out appendBytes:"\""
              length:1];

   c      = (char *) [s UTF8String];
   length = c ? strlen( c) : 0;
   for( i = 0; i < length; i++)
   {
      ch = (unsigned char) c[ i];
      switch( ch)
      {
      case '"'  : [out appendBytes:"\\\"" length:2]; break;
      case '\\' : [out appendBytes:"\\\\" length:2]; break;
      case '\n' : [out appendBytes:"\\n"  length:2]; break;
      case '\r' : [out appendBytes:"\\r"  length:2]; break;
      case '\t' : [out appendBytes:"\\t"  length:2]; break;

      default :
         if( ch < 0x20)
         {
            escape[ 0] = '\\';
            escape[ 1] = 'x';
            escape[ 2] = hex[ ch >> 4];
            escape[ 3] = hex[ ch & 0xF];
            [out appendBytes:escape
                       length:4];
         }
         else
            [out appendBytes:&ch
                       length:1];
         break;
      }
   }
   [out appendBytes:"\""
              length:1];

   return( [NSString mulleStringWithUTF8Characters:[out bytes]
                                            length:[out length]]);
}


static NSString   *yamlStringScalar( NSString *s)
{
   if( yamlStringCanBePlain( s))
      return( s);
   return( yamlDoubleQuotedString( s));
}


static BOOL   yamlNumberIsBoolean( NSNumber *number)
{
   static Class   boolClass;
   static BOOL    didLookup;

   if( ! didLookup)
   {
      boolClass = NSClassFromString( @"_MulleObjCBoolNumber");
      didLookup = YES;
   }
   return( boolClass && [number isKindOfClass:boolClass]);
}


static NSString   *yamlNumberScalar( NSNumber *number)
{
   char       *type;
   double     value;
   NSString   *s;

   if( yamlNumberIsBoolean( number))
      return( [number boolValue] ? @"true" : @"false");

   value = [number doubleValue];
   if( isnan( value))
      return( @".nan");
   if( isinf( value))
      return( value < 0.0 ? @"-.inf" : @".inf");

   type = [number objCType];
   s    = [number stringValue];

   // make sure a floating point number does not come back as an integer
   if( type && (type[ 0] == 'f' || type[ 0] == 'd' || type[ 0] == 'D'))
      if( [s rangeOfString:@"."].location == NSNotFound
          && [s rangeOfString:@"e"].location == NSNotFound
          && [s rangeOfString:@"E"].location == NSNotFound)
         s = [s stringByAppendingString:@".0"];

   return( s);
}


//
// Returns nil exactly for a container that needs a block representation,
// everything else (including empty containers and unknown objects) becomes
// a single line.
//
static NSString   *yamlInlineScalar( id object)
{
   if( [object isKindOfClass:[NSArray class]])
      return( [object count] ? nil : @"[]");
   if( [object isKindOfClass:[NSDictionary class]])
      return( [object count] ? nil : @"{}");
   if( object == [NSNull null])
      return( @"null");
   if( [object isKindOfClass:[NSNumber class]])
      return( yamlNumberScalar( (NSNumber *) object));
   if( [object isKindOfClass:[NSString class]])
      return( yamlStringScalar( (NSString *) object));
   return( yamlStringScalar( [object description]));
}


//
// Keys are always scalars, even if a hand built dictionary carries something
// else. Those fall back to a quoted description.
//
static NSString   *yamlKeyScalar( id key)
{
   NSString   *s;

   s = yamlInlineScalar( key);
   if( s)
      return( s);
   return( yamlDoubleQuotedString( [key description]));
}


static NSComparisonResult   yamlKeyCompare( id a, id b, void *context)
{
   return( [yamlKeyScalar( a) compare:yamlKeyScalar( b)]);
}


static NSArray   *yamlSortedKeys( NSDictionary *dictionary)
{
   return( [[dictionary allKeys] sortedArrayUsingFunction:yamlKeyCompare
                                                  context:NULL]);
}


static NSString   *yamlIndentString( NSUInteger width)
{
   NSMutableString   *s;
   NSUInteger        i;

   s = [NSMutableString string];
   for( i = 0; i < width; i++)
      [s appendString:@" "];
   return( s);
}


@interface MulleYAMLWriter( Private)

- (NSArray *) linesForObject:(id) object;

@end


@implementation MulleYAMLWriter

@method_implementation +writer = +instance;


- (id) init
{
   _indentWidth = 2;
   _sortsKeys   = YES;
   return( self);
}


- (NSUInteger) indentWidth
{
   return( _indentWidth);
}


- (void) setIndentWidth:(NSUInteger) width
{
   _indentWidth = width;
}


- (BOOL) sortsKeys
{
   return( _sortsKeys);
}


- (void) setSortsKeys:(BOOL) flag
{
   _sortsKeys = flag;
}


+ (NSData *) dataWithPropertyList:(id) plist
{
   return( [[self writer] dataFromPropertyList:plist]);
}


+ (NSString *) stringWithPropertyList:(id) plist
{
   return( [[self writer] stringFromPropertyList:plist]);
}


- (NSArray *) linesForObject:(id) object
{
   NSMutableArray   *lines;
   NSArray          *child;
   NSArray          *keys;
   NSString         *keyString;
   NSString         *line;
   NSString         *prefix;
   NSString         *scalar;
   id               item;
   id               key;
   id               value;
   NSUInteger       i;
   NSUInteger       j;
   NSUInteger       n;
   NSUInteger       m;

   scalar = yamlInlineScalar( object);
   if( scalar)
      return( [NSArray arrayWithObject:scalar]);

   lines = [NSMutableArray array];

   if( [object isKindOfClass:[NSArray class]])
   {
      for( item in object)
      {
         child = [self linesForObject:item];
         [lines addObject:[@"- " stringByAppendingString:[child objectAtIndex:0]]];
         for( i = 1, n = [child count]; i < n; i++)
            [lines addObject:[@"  " stringByAppendingString:[child objectAtIndex:i]]];
      }
      return( lines);
   }

   // NSDictionary
   keys   = yamlSortedKeys( (NSDictionary *) object);
   prefix = yamlIndentString( _indentWidth);
   for( i = 0, n = [keys count]; i < n; i++)
   {
      key       = [keys objectAtIndex:i];
      value     = [object objectForKey:key];
      keyString = yamlKeyScalar( key);
      scalar    = yamlInlineScalar( value);

      if( scalar)
      {
         line = [[keyString stringByAppendingString:@": "]
                    stringByAppendingString:scalar];
         [lines addObject:line];
         continue;
      }

      [lines addObject:[keyString stringByAppendingString:@":"]];

      child = [self linesForObject:value];
      for( j = 0, m = [child count]; j < m; j++)
         [lines addObject:[prefix stringByAppendingString:[child objectAtIndex:j]]];
   }
   return( lines);
}


- (NSString *) stringFromPropertyList:(id) plist
{
   NSMutableString   *out;
   NSArray           *lines;
   NSUInteger        i;
   NSUInteger        n;

   if( ! plist)
      return( @"");

   lines = [self linesForObject:plist];
   out   = [NSMutableString string];
   for( i = 0, n = [lines count]; i < n; i++)
   {
      if( i)
         [out appendString:@"\n"];
      [out appendString:[lines objectAtIndex:i]];
   }
   [out appendString:@"\n"];
   return( out);
}


- (NSData *) dataFromPropertyList:(id) plist
{
   return( [[self stringFromPropertyList:plist] dataUsingEncoding:NSUTF8StringEncoding]);
}


- (void) writePropertyList:(id) plist
                  toStream:(id <MulleObjCOutputStream>) stream
{
   char         *s;
   NSString     *text;
   NSUInteger   length;

   text = [self stringFromPropertyList:plist];
   if( ! [text length])
      return;

   s      = (char *) [text UTF8String];
   length = strlen( s);
   [stream mulleWriteBytes:s
                    length:length];
}

@end


@implementation NSObject( MulleYAMLWriter)

- (void) mullePrintYAMLToStream:(id <MulleObjCOutputStream>) stream
{
   [[MulleYAMLWriter writer] writePropertyList:self
                                      toStream:stream];
}

@end
