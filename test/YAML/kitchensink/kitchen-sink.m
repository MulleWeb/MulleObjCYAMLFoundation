#import <MulleObjCYAMLFoundation/MulleObjCYAMLFoundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


//
// Reads "kitchen-sink.yaml", which lives next to the compiled test, parses
// it, writes it back out as YAML and parses that again. The two property
// lists must be equal, which is the real back and forth conversion check.
//

static char   *dirOfExecutable( char *argv0)
{
   char     *dir;
   char     *slash;

   dir = strdup( argv0);

   slash = strrchr( dir, '/');
#ifdef _WIN32
   if( ! slash)
      slash = strrchr( dir, '\\');
#endif
   if( slash)
      *slash = 0;
   return( dir);
}


static char   *readFile( char *path)
{
   FILE   *fp;
   char   *buffer;
   long   size;

   fp = fopen( path, "rb");
   if( ! fp)
      return( NULL);

   fseek( fp, 0, SEEK_END);
   size = ftell( fp);
   fseek( fp, 0, SEEK_SET);

   if( size < 0)
   {
      fclose( fp);
      return( NULL);
   }

   buffer = malloc( (size_t) size + 1);
   if( ! buffer)
   {
      fclose( fp);
      return( NULL);
   }

   if( fread( buffer, 1, (size_t) size, fp) != (size_t) size)
   {
      free( buffer);
      fclose( fp);
      return( NULL);
   }

   buffer[ size] = 0;
   fclose( fp);
   return( buffer);
}


static void   show( NSString *key, id value)
{
   if( ! value)
   {
      mulle_printf( "  %-16@ (absent)\n", key);
      return;
   }
   mulle_printf( "  %-16@ %@\n", key, value);
}


int   main( int argc, char *argv[])
{
   MulleYAMLParser        *parser;
   NSPropertyListFormat   format;
   NSData                 *data;
   NSData                 *output;
   NSError                *error;
   NSString               *text;
   id                     plist;
   id                     again;
   char                   *dir;
   char                   *path;
   char                   *content;
   size_t                 length;

#if defined( __MULLE_OBJC__)
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   dir  = dirOfExecutable( argv[ 0]);
   path = malloc( strlen( dir) + strlen( "/kitchen-sink.yaml") + 1);
   sprintf( path, "%s/kitchen-sink.yaml", dir);
   free( dir);

   content = readFile( path);
   if( ! content)
      content = readFile( "kitchen-sink.yaml");
   if( ! content)
   {
      mulle_printf( "could not read kitchen-sink.yaml (tried %s)\n", path);
      free( path);
      return( 1);
   }
   free( path);

   length = strlen( content);
   data   = [NSData dataWithBytes:content
                           length:length];
   free( content);

   //
   // 1. YAML -> property list
   //
   parser = [MulleYAMLParser parser];
   plist  = [parser parseData:data];
   if( ! plist)
   {
      mulle_printf( "parse failed: %@\n", [parser problem]);
      return( 1);
   }

   //
   // 2. property list -> YAML
   //
   error  = nil;
   output = [NSPropertyListSerialization dataWithPropertyList:plist
                                                       format:MullePropertyListYAMLFormat
                                                      options:0
                                                        error:&error];
   if( ! output)
   {
      mulle_printf( "write failed: %@\n", [error localizedDescription]);
      return( 1);
   }

   //
   // 3. YAML -> property list again
   //
   format = MullePropertyListYAMLFormat;
   again  = [NSPropertyListSerialization mullePropertyListFromData:output
                                                  mutabilityOption:0
                                                            format:&format
                                                      formatOption:MullePropertyListFormatOptionForce];
   if( ! again)
   {
      mulle_printf( "reparse failed\n");
      return( 1);
   }

   //
   // 4. the two property lists must be the same
   //
   if( ! [again isEqual:plist])
   {
      mulle_printf( "roundtrip mismatch\n  first : %@\n  second: %@\n", plist, again);
      return( 1);
   }

   mulle_printf( "roundtrip ok, %lu top level keys\n",
                  (unsigned long) [plist count]);

   mulle_printf( "== values after the round trip\n");
   show( @"title",        [again objectForKey:@"title"]);
   show( @"flag",         [again objectForKey:@"flag"]);
   show( @"nothing",      [again objectForKey:@"nothing"]);
   show( @"octal",        [again objectForKey:@"octal"]);
   show( @"infinity",     [again objectForKey:@"infinity"]);
   show( @"as_string_num", [again objectForKey:@"as_string_num"]);
   show( @"admin",        [[again objectForKey:@"author"] objectForKey:@"admin"]);
   show( @"size",         [[again objectForKey:@"merged"] objectForKey:@"size"]);
   show( @"deepest",      [[[again objectForKey:@"nested"] objectForKey:@"deeper"] objectForKey:@"deepest"]);

   //
   // and show the normalized YAML that the writer produced
   //
   text = [[[NSString alloc] initWithData:output
                                 encoding:NSUTF8StringEncoding] autorelease];
   mulle_printf( "== normalized yaml\n%@", text);

   return( 0);
}
