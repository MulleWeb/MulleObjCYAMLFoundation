#import <MulleObjCYAMLFoundation/MulleObjCYAMLFoundation.h>


//
// The plist type, not the class: which concrete NSString subclass came back
// is an implementation detail, that it is a string and not a number is not.
//
static char   *typeName( id value)
{
   if( [value isKindOfClass:[NSNull class]])
      return( "null");
   if( [value isKindOfClass:[NSNumber class]])
      return( "number");
   if( [value isKindOfClass:[NSString class]])
      return( "string");
   if( [value isKindOfClass:[NSArray class]])
      return( "array");
   if( [value isKindOfClass:[NSDictionary class]])
      return( "dict");
   return( "unknown");
}


//
// Dictionaries have no defined enumeration order, so this prints named keys
// instead of whole containers. The class name is printed too, because the
// whole point of the exercise is that "yes" becomes a boolean and "08" does
// not become a number.
//
static void   show( NSString *key, id value)
{
   if( ! value)
   {
      mulle_printf( "  %-14@ (absent)\n", key);
      return;
   }
   mulle_printf( "  %-14@ %-10s %@\n", key, typeName( value), value);
}


int   main( int argc, char *argv[])
{
   MulleYAMLParser          *parser;
   NSData                   *data;
   NSDictionary             *plist;
   NSPropertyListFormat     format;
   NSString                 *text;
   id                       value;

#if defined( __MULLE_OBJC__)
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   //
   // 1. the point of the whole framework: YAML as a property list format
   //
   mulle_printf( "== YAML as a property list format\n");

   text = @"title: My Post\n"
           "layout: post\n"
           "tags:\n"
           "  - one\n"
           "  - two\n"
           "author:\n"
           "  name: Nat\n"
           "  admin: yes\n";

   format = MullePropertyListYAMLFormat;
   plist  = [NSPropertyListSerialization mullePropertyListFromData:[text dataUsingEncoding:NSUTF8StringEncoding]
                                                mutabilityOption:0
                                                          format:&format
                                                    formatOption:MullePropertyListFormatOptionForce];

   mulle_printf( "  format         %@\n", MulleStringFromPropertListFormatString( format));
   show( @"title",  [plist objectForKey:@"title"]);
   show( @"tags",   [plist objectForKey:@"tags"]);
   show( @"name",   [[plist objectForKey:@"author"] objectForKey:@"name"]);
   show( @"admin",  [[plist objectForKey:@"author"] objectForKey:@"admin"]);

   //
   // 2. implicit typing, which is where YAML and Jekyll get interesting
   //
   mulle_printf( "== implicit typing\n");

   text   = @"yes_bool: yes\n"
             "no_bool: no\n"
             "on_bool: on\n"
             "off_bool: off\n"
             "quoted_yes: \"yes\"\n"
             "int_dec: 42\n"
             "int_octal: 010\n"
             "int_hex: 0x1f\n"
             "int_bin: 0b101\n"
             "int_under: 1_000\n"
             "float_plain: 1.20\n"
             "float_inf: .inf\n"
             "null_tilde: ~\n"
             "str_08: 08\n";
   plist  = [text mulleYAML];

   show( @"yes_bool",    [plist objectForKey:@"yes_bool"]);
   show( @"no_bool",     [plist objectForKey:@"no_bool"]);
   show( @"on_bool",     [plist objectForKey:@"on_bool"]);
   show( @"off_bool",    [plist objectForKey:@"off_bool"]);
   show( @"quoted_yes",  [plist objectForKey:@"quoted_yes"]);
   show( @"int_dec",     [plist objectForKey:@"int_dec"]);
   show( @"int_octal",   [plist objectForKey:@"int_octal"]);
   show( @"int_hex",     [plist objectForKey:@"int_hex"]);
   show( @"int_bin",     [plist objectForKey:@"int_bin"]);
   show( @"int_under",   [plist objectForKey:@"int_under"]);
   show( @"float_plain", [plist objectForKey:@"float_plain"]);
   show( @"float_inf",   [plist objectForKey:@"float_inf"]);
   show( @"null_tilde",  [plist objectForKey:@"null_tilde"]);
   show( @"str_08",      [plist objectForKey:@"str_08"]);

   //
   // 3. block sequences, flow sequences and a nested mapping
   //
   mulle_printf( "== structures\n");

   text  = @"flow: [ 1, 2, 3 ]\n"
            "block:\n"
            "   - a\n"
            "   - b\n"
            "nested:\n"
            "   inner:\n"
            "      deep: 7\n";
   plist = [text mulleYAML];

   show( @"flow",  [plist objectForKey:@"flow"]);
   show( @"block", [plist objectForKey:@"block"]);
   show( @"deep",  [[[plist objectForKey:@"nested"] objectForKey:@"inner"] objectForKey:@"deep"]);

   //
   // 4. a merge key, which is the one piece of YAML people actually use in
   //    configuration files
   //
   mulle_printf( "== merge key\n");

   text  = @"defaults: &defaults\n"
            "   a: 1\n"
            "   b: 2\n"
            "merged:\n"
            "   <<: *defaults\n"
            "   b: 20\n";
   plist = [text mulleYAML];

   show( @"a", [[plist objectForKey:@"merged"] objectForKey:@"a"]);
   show( @"b", [[plist objectForKey:@"merged"] objectForKey:@"b"]);

   //
   // 5. failure is API detectable, not just a line on stderr
   //
   mulle_printf( "== errors\n");

   parser = [MulleYAMLParser parser];
   value  = [parser parseData:[@"a: b\n  c: d\n" dataUsingEncoding:NSUTF8StringEncoding]];
   mulle_printf( "  bad mapping    %s\n", value ? "parsed" : "nil");
   mulle_printf( "  line           %lu\n", (unsigned long) [parser line]);
   mulle_printf( "  problem        %@\n", [parser problem]);

   parser = [MulleYAMLParser parser];
   value  = [parser parseData:[@"? [ a, b ]\n: 1\n" dataUsingEncoding:NSUTF8StringEncoding]];
   mulle_printf( "  non-scalar key %s\n", value ? "parsed" : "nil");
   mulle_printf( "  problem        %@\n", [parser problem]);

   //
   // 6. an empty document is an empty dictionary, unless you say otherwise
   //
   mulle_printf( "== empty document\n");

   parser = [MulleYAMLParser parser];
   show( @"empty", [parser parseData:[NSData data]]);

   parser = [MulleYAMLParser parser];
   [parser setNilOnEmptyDocument:YES];
   mulle_printf( "  nil instead    %s\n", [parser parseData:[NSData data]] ? "no" : "yes");

   return( 0);
}
