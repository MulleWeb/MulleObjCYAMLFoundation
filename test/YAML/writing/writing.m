#import <MulleObjCYAMLFoundation/MulleObjCYAMLFoundation.h>

#include <math.h>


//
// Writes property lists with the plist API and prints the resulting YAML, so
// the golden file documents the exact output.
//
static void   showYAML( NSString *label, id plist)
{
   NSError    *error;
   NSData     *data;
   NSString   *text;

   error = nil;
   data  = [NSPropertyListSerialization dataWithPropertyList:plist
                                                      format:MullePropertyListYAMLFormat
                                                     options:0
                                                       error:&error];
   if( ! data)
   {
      mulle_printf( "== %@\n  write failed: %@\n", label, [error localizedDescription]);
      return;
   }

   text = [[[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding] autorelease];
   mulle_printf( "== %@\n%@", label, text);
}


int   main( int argc, char *argv[])
{
   id   plist;

#if defined( __MULLE_OBJC__)
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   //
   // basic mapping, keys come out sorted and implicit types are preserved
   //
   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               @"My Post",                    @"title",
               @"post",                       @"layout",
               [NSNumber numberWithBool:YES], @"published",
               [NSNumber numberWithInt:42],   @"count",
               [NSNumber numberWithDouble:1.2], @"ratio",
               [NSNull null],                 @"subtitle",
               nil];
   showYAML( @"mapping", plist);

   //
   // strings that the reader would otherwise turn into numbers, booleans,
   // nulls or structure have to be quoted
   //
   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               @"yes",       @"bool_word",
               @"08",        @"leading_zero",
               @"1.20",      @"float_word",
               @"1e5",       @"exponent_word",
               @"null",      @"null_word",
               @"~",         @"tilde",
               @"",          @"empty",
               @"a: b",      @"colon",
               @"- lead",    @"dash",
               @"# hash",    @"hash",
               @"plain",     @"plain",
               @"naïve café — 日本語", @"unicode",
               @"say \"hi\"", @"quotes",
               nil];
   showYAML( @"quoting", plist);

   //
   // nesting: a mapping in a mapping, a sequence in a mapping
   //
   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSDictionary dictionaryWithObjectsAndKeys:
                  @"Nat",                       @"name",
                  [NSNumber numberWithBool:NO], @"admin",
                  nil],                         @"author",
               [NSArray arrayWithObjects:@"one", @"two", nil], @"tags",
               nil];
   showYAML( @"nested", plist);

   //
   // sequences: scalars, mappings and sequences inside a sequence
   //
   plist = [NSArray arrayWithObjects:
               @"a",
               @"b",
               [NSDictionary dictionaryWithObjectsAndKeys:
                  [NSNumber numberWithInt:1], @"x",
                  [NSNumber numberWithInt:2], @"y",
                  nil],
               [NSArray arrayWithObjects:@"c", @"d", nil],
               nil];
   showYAML( @"sequences", plist);

   //
   // empty containers survive as flow collections
   //
   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSDictionary dictionary], @"empty_map",
               [NSArray array],           @"empty_seq",
               nil];
   showYAML( @"empty", plist);

   //
   // scalar roots
   //
   showYAML( @"root_string", @"hello");
   showYAML( @"root_number", [NSNumber numberWithInt:-7]);
   showYAML( @"root_bool",   [NSNumber numberWithBool:YES]);

   //
   // float edge cases: inf and nan get the YAML spellings. Note that the
   // framework canonicalizes an integral double, so 1.0 is stored and
   // written as the integer 1.
   //
   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSNumber numberWithDouble:2.5],      @"half",
               [NSNumber numberWithDouble:HUGE_VAL],  @"inf",
               [NSNumber numberWithDouble:-HUGE_VAL], @"neg_inf",
               [NSNumber numberWithDouble:NAN],  @"nan",
               nil];
   showYAML( @"floats", plist);

   return( 0);
}
