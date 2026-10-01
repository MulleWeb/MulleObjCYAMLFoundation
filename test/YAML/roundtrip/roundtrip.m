#import <MulleObjCYAMLFoundation/MulleObjCYAMLFoundation.h>

#include <math.h>


static int   failures;


//
// Write a property list as YAML, read it back and compare. This is the
// contract that matters: a plist that goes through MulleYAMLWriter and
// MulleYAMLParser comes back equal.
//
static void   check( NSString *label, id original)
{
   NSError                *error;
   NSData                 *data;
   NSPropertyListFormat   format;
   id                     parsed;

   error = nil;
   data  = [NSPropertyListSerialization dataWithPropertyList:original
                                                      format:MullePropertyListYAMLFormat
                                                     options:0
                                                       error:&error];
   if( ! data)
   {
      mulle_printf( "FAIL %@ write: %@\n", label, [error localizedDescription]);
      failures++;
      return;
   }

   format = MullePropertyListYAMLFormat;
   parsed = [NSPropertyListSerialization mullePropertyListFromData:data
                                                  mutabilityOption:0
                                                            format:&format
                                                      formatOption:MullePropertyListFormatOptionForce];
   if( ! parsed)
   {
      mulle_printf( "FAIL %@ parse\n", label);
      failures++;
      return;
   }

   if( ! [parsed isEqual:original])
   {
      mulle_printf( "FAIL %@\n  in : %@\n  out: %@\n", label, original, parsed);
      failures++;
      return;
   }

   mulle_printf( "ok   %@\n", label);
}


int   main( int argc, char *argv[])
{
   id   plist;

#if defined( __MULLE_OBJC__)
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   check( @"scalar string", @"hello world");
   check( @"scalar int",    [NSNumber numberWithInt:-42]);
   check( @"scalar float",  [NSNumber numberWithDouble:1.2]);
   check( @"scalar float1", [NSNumber numberWithDouble:1.0]);
   check( @"scalar bool",   [NSNumber numberWithBool:YES]);
   check( @"null",          [NSNull null]);
   check( @"empty string",  @"");
   check( @"string bool",   @"yes");
   check( @"string octal",  @"08");
   check( @"string float",  @"1.20");
   check( @"unicode",       @"naïve café — 日本語");
   check( @"quotes",        @"say \"hi\" and \\ bye");
   check( @"newline",       @"first\nsecond");

   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               @"My Post",                       @"title",
               @"post",                          @"layout",
               [NSNumber numberWithBool:YES],    @"published",
               [NSNumber numberWithInt:42],      @"count",
               [NSNumber numberWithDouble:1.2],  @"ratio",
               [NSNull null],                    @"subtitle",
               nil];
   check( @"flat mapping", plist);

   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSDictionary dictionaryWithObjectsAndKeys:
                  @"Nat",                        @"name",
                  [NSNumber numberWithBool:NO],  @"admin",
                  nil],                          @"author",
               [NSArray arrayWithObjects:@"one", @"two", nil], @"tags",
               nil];
   check( @"nested mapping", plist);

   plist = [NSArray arrayWithObjects:
               @"a",
               @"b",
               [NSDictionary dictionaryWithObjectsAndKeys:
                  [NSNumber numberWithInt:1], @"x",
                  [NSNumber numberWithInt:2], @"y",
                  nil],
               [NSArray arrayWithObjects:@"c", @"d", nil],
               nil];
   check( @"nested sequence", plist);

   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSDictionary dictionary], @"empty_map",
               [NSArray array],           @"empty_seq",
               nil];
   check( @"empty containers", plist);

   //
   // a bunch of strings that could be mistaken for core scalars
   //
   plist = [NSDictionary dictionaryWithObjectsAndKeys:
               @"yes",     @"a",
               @"08",      @"b",
               @"1.20",    @"c",
               @"1e5",     @"d",
               @"null",    @"e",
               @"~",       @"f",
               @"",        @"g",
               @"a: b",    @"h",
               @"- lead",  @"i",
               @"# hash",  @"j",
               @"true",    @"k",
               @"plain",   @"l",
               nil];
   check( @"quoting", plist);

   if( failures)
   {
      mulle_printf( "%d failure(s)\n", failures);
      return( 1);
   }
   mulle_printf( "all roundtrips passed\n");
   return( 0);
}
