//
//  MulleYAMLWriter.h
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
#import "import.h"

@class NSData;
@class NSString;


//
// MulleYAMLWriter is the counterpart of MulleYAMLParser: it turns a property
// list (NSDictionary, NSArray, NSString, NSNumber and NSNull) back into a
// YAML document.
//
// It writes block style YAML. A string that the reader would resolve to a
// number, boolean or null is double quoted, so that round tripping through
// MulleYAMLParser preserves its type.
//
@interface MulleYAMLWriter : NSObject
{
   NSUInteger   _indentWidth;
   BOOL         _sortsKeys;
}

// a fresh writer, one per document
+ (instancetype) writer;

// convenience, using default settings
+ (NSData *) dataWithPropertyList:(id) plist;
+ (NSString *) stringWithPropertyList:(id) plist;

- (NSData *) dataFromPropertyList:(id) plist;
- (NSString *) stringFromPropertyList:(id) plist;

- (void) writePropertyList:(id) plist
                  toStream:(id <MulleObjCOutputStream>) stream;

// spaces per nesting level, 2 by default
@property( assign) NSUInteger  indentWidth;

// dictionary keys are printed sorted by default, which makes the output
// deterministic
@property( assign) BOOL  sortsKeys;

@end


//
// This is the entry point NSPropertyListSerialization uses for
// MullePropertyListYAMLFormat. It is installed in the +load of
// NSPropertyListSerialization( YAML).
//
@interface NSObject( MulleYAMLWriter)

- (void) mullePrintYAMLToStream:(id <MulleObjCOutputStream>) stream;

@end
