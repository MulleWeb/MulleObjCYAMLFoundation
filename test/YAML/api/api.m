#import <MulleObjCYAMLFoundation/MulleObjCYAMLFoundation.h>

#include <stdio.h>


//
// YAML has no magic bytes, so it is found with a format detector that looks
// for things no other plist format has: a "key:" mapping, a block sequence or
// a document marker. A flow collection is not claimed, because it looks just
// like JSON. Forcing the format always works, even for flow collections.
//
static void   detect( NSString *label, NSString *yaml)
{
   NSPropertyListFormat   format;
   NSError                *error;
   NSData                 *data;
   id                     plist;

   data   = [yaml dataUsingEncoding:NSUTF8StringEncoding];
   format = 0;                       // no hint, pure detection
   error  = nil;
   @try
   {
      plist = [NSPropertyListSerialization propertyListWithData:data
                                                        options:0
                                                         format:&format
                                                          error:&error];
      mulle_printf( "  %-10@ %-8s format=%-8@ %@\n",
                     label,
                     plist ? "parsed" : "nil",
                     MulleStringFromPropertListFormatString( format),
                     plist ? plist : @"");
   }
   @catch( id exception)
   {
      mulle_printf( "  %-10@ exception: %@\n", label, exception);
   }
}


static void   force( NSString *label, NSString *yaml)
{
   NSPropertyListFormat   format;
   NSData                 *data;
   id                     plist;

   data   = [yaml dataUsingEncoding:NSUTF8StringEncoding];
   format = MullePropertyListYAMLFormat;
   plist  = [NSPropertyListSerialization mullePropertyListFromData:data
                                                  mutabilityOption:0
                                                            format:&format
                                                      formatOption:MullePropertyListFormatOptionForce];
   mulle_printf( "  %-10@ %-8s format=%-8@ %@\n",
                  label,
                  plist ? "parsed" : "nil",
                  MulleStringFromPropertListFormatString( format),
                  plist ? plist : @"");
}


int   main( int argc, char *argv[])
{
#if defined( __MULLE_OBJC__)
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   mulle_printf( "== detected as YAML\n");
   detect( @"mapping",  @"title: My Post\ntags:\n   - one\n   - two\n");
   detect( @"sequence", @"- one\n- two\n");
   detect( @"document", @"---\ntitle: My Post\n");
   detect( @"comment",  @"# a comment\n\ntitle: My Post\n");

   mulle_printf( "== detected as something else\n");
   detect( @"openstep", @"{ a = b; }\n");
   detect( @"flow",     @"[ one, two ]\n");

   mulle_printf( "== forced YAML\n");
   force( @"flow",      @"[ one, two ]\n");
   force( @"mapping",   @"title: My Post\ntags:\n   - one\n   - two\n");

   return( 0);
}
