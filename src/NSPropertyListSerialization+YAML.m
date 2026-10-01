//
//  NSPropertyListSerialization+YAML.m
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
#import "MulleYAMLWriter.h"

// other libraries of MulleObjCPlistFoundation


// std-c and dependencies
#include <ctype.h>
#include <string.h>


@interface NSPropertyListSerialization( YAML)

+ (NSPropertyListFormat) mulleDetectYAMLFormat:(NSData *) data;

@end


@implementation NSPropertyListSerialization( YAML)

@dependency MulleYAMLParser;

// YAML has no magic bytes, but a document that starts with a "key:" mapping,
// a block sequence or a "---" marker is not valid OpenStep (which uses '=')
// nor JSON (which starts with '[' or '{'). Those are detected. A flow
// collection is left to the other detectors, because it is indistinguishable
// from JSON.
+ (void) load
{
   [self mulleAddFormatDetector:@selector( mulleDetectYAMLFormat:)];

   [self mulleAddParserClass:[MulleYAMLParser class]
                      method:@selector( parseData:)
       forPropertyListFormat:MullePropertyListYAMLFormat];

   [self mulleAddPrintMethod:@selector( mullePrintYAMLToStream:)
        forPropertyListFormat:MullePropertyListYAMLFormat];
}


+ (NSPropertyListFormat) mulleDetectYAMLFormat:(NSData *) data
{
   char         *s;
   NSUInteger   i;
   NSUInteger   j;
   NSUInteger   len;

   s   = [data bytes];
   len = [data length];
   if( ! s || ! len)
      return( 0);

   for( i = 0; i < len; )
   {
      // start of a line
      while( i < len && (s[ i] == ' ' || s[ i] == '\t'))
         i++;
      if( i >= len)
         break;

      // blank line or comment
      if( s[ i] == '\n' || s[ i] == '\r' || s[ i] == '#')
      {
         while( i < len && s[ i] != '\n')
            i++;
         if( i < len)
            i++;
         continue;
      }

      // document marker or directive
      if( i + 3 <= len && ! strncmp( &s[ i], "---", 3))
         return( MullePropertyListYAMLFormat);
      if( s[ i] == '%')
         return( MullePropertyListYAMLFormat);

      // a flow collection or an OpenStep collection, let the other
      // detectors decide
      if( s[ i] == '{' || s[ i] == '[' || s[ i] == '<' || s[ i] == '(')
         return( 0);

      // block sequence
      if( s[ i] == '-' && (i + 1 >= len || s[ i + 1] == ' ' || s[ i + 1] == '\n' || s[ i + 1] == '\r'))
         return( MullePropertyListYAMLFormat);

      // "key:" where key is a plain identifier and ':' is followed by a
      // space or the end of the line
      for( j = i; j < len; j++)
         if( ! (isalnum( (unsigned char) s[ j]) || s[ j] == '_' || s[ j] == '-'
                || s[ j] == '.' || s[ j] == '/'))
            break;
      if( j > i && j < len && s[ j] == ':'
          && (j + 1 >= len || s[ j + 1] == ' ' || s[ j + 1] == '\n' || s[ j + 1] == '\r'))
         return( MullePropertyListYAMLFormat);

      return( 0);
   }
   return( 0);
}

@end
