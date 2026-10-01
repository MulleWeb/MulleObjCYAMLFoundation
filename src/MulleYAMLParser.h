//
//  MulleYAMLParser.h
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


//
// MulleYAMLParser reads YAML and produces a property list: NSDictionary,
// NSArray, NSString, NSNumber and NSNull. It uses libyaml, which is the same
// engine Ruby's Psych uses, so plain scalars resolve the way they do in
// Jekyll: "yes" is a boolean, "08" is a string and "1.20" is a float.
//
// The root of a YAML document is usually a mapping or a sequence, but a
// document that is only a scalar parses fine too. "<<" merge keys are
// honoured; a mapping's own keys win over merged ones.
//
// Returned as strings, not converted: !!timestamp, the sexagesimal numeric
// forms ("1:30") and !!binary. A mapping key that is itself a collection is
// refused, because such a key cannot be a dictionary key.
//
// Known quirk: an explicit tag is honoured, except that a plain (unquoted)
// "!!str" is still resolved by the core schema, because libyaml reports a
// missing tag and "!!str" in the same way. So "!!str 123" parses as the
// number 123, while "!!str \"123\"" parses as the string "123". This is
// documented, not fixed.
//
@interface MulleYAMLParser : NSObject

// a fresh parser, one per document
+ (instancetype) parser;

// On failure returns nil, sets the generic NSError and remembers where it
// went wrong in -problem, -line and -column.
- (id) parseData:(NSData *) data;

// A document that carries no node at all - an empty file, or just "---" -
// yields an empty NSDictionary, which is what a Jekyll file with an empty
// frontmatter block should mean. Set this to get nil instead.
@property( assign) BOOL  nilOnEmptyDocument;

@property( readonly, assign) NSUInteger  line;     // 1 based, 0 if unknown
@property( readonly, assign) NSUInteger  column;   // 1 based, 0 if unknown
@property( readonly, retain) NSString   *problem;

@end


@interface NSString( MulleYAMLParser)

- (id) mulleYAML;

@end
