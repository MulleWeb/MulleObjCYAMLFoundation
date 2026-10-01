#import <MulleObjCYAMLFoundation/MulleObjCYAMLFoundation.h>


//
// A few more corners of the reader than the parse test covers: block scalars,
// explicit tags, flow collections, anchors and aliases, and documents whose
// root is not a mapping.
//
static char   *typeName( id value)
{
   if( ! value)
      return( "nil");
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


static void   show( NSString *key, id value)
{
   if( ! value)
   {
      mulle_printf( "  %-14@ (absent)\n", key);
      return;
   }
   mulle_printf( "  %-14@ %-10s %@\n", key, typeName( value), value);
}


static NSDictionary   *parse( NSString *text)
{
   MulleYAMLParser   *parser;
   id                plist;

   parser = [MulleYAMLParser parser];
   plist  = [parser parseData:[text dataUsingEncoding:NSUTF8StringEncoding]];
   if( ! [plist isKindOfClass:[NSDictionary class]])
   {
      mulle_printf( "  unexpected root: %s\n", typeName( plist));
      return( nil);
   }
   return( plist);
}


int   main( int argc, char *argv[])
{
   MulleYAMLParser   *parser;
   NSDictionary      *plist;
   id                value;

#if defined( __MULLE_OBJC__)
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   //
   // block scalars are never resolved, even if they look like a number
   //
   mulle_printf( "== block scalars\n");
   plist = parse( @"literal: |\n"
                  "   yes\n"
                  "   second line\n"
                  "folded: >\n"
                  "   a folded\n"
                  "   line\n");
   show( @"literal", [plist objectForKey:@"literal"]);
   show( @"folded",  [plist objectForKey:@"folded"]);

   //
   // explicit tags. A tag on a quoted scalar forces the type, but the reader
   // resolves a plain "!!str" through the core schema anyway (that is a
   // documented quirk of the reader, not of YAML)
   //
   mulle_printf( "== explicit tags\n");
   plist = parse( @"str_quoted: !!str \"123\"\n"
                  "str_plain: !!str 123\n"
                  "int_str: !!int 42\n"
                  "float_str: !!float 1.5\n"
                  "bool_str: !!bool yes\n"
                  "null_str: !!null whatever\n");
   show( @"str_quoted", [plist objectForKey:@"str_quoted"]);
   show( @"str_plain",  [plist objectForKey:@"str_plain"]);
   show( @"int_str",    [plist objectForKey:@"int_str"]);
   show( @"float_str",  [plist objectForKey:@"float_str"]);
   show( @"bool_str",   [plist objectForKey:@"bool_str"]);
   show( @"null_str",   [plist objectForKey:@"null_str"]);

   //
   // quoting styles: single, double with escapes and a quoted "yes"
   //
   mulle_printf( "== quoting\n");
   plist = parse( @"single: 'yes'\n"
                  "double: \"a\\tb\\n\"\n"
                  "plain_num: 08\n");
   show( @"single",    [plist objectForKey:@"single"]);
   show( @"double",    [plist objectForKey:@"double"]);
   show( @"plain_num", [plist objectForKey:@"plain_num"]);

   //
   // flow collections parsed as if they had been written in block style
   //
   mulle_printf( "== flow collections\n");
   plist = parse( @"map: { a: 1, b: 2 }\n"
                  "seq: [ one, two, three ]\n");
   show( @"a", [ [plist objectForKey:@"map"] objectForKey:@"a"]);
   show( @"b", [ [plist objectForKey:@"map"] objectForKey:@"b"]);
   show( @"seq", [plist objectForKey:@"seq"]);

   //
   // anchors and aliases, and a merge key from a sequence of mappings
   //
   mulle_printf( "== anchors and merge\n");
   plist = parse( @"first: &first\n"
                  "   alpha: 1\n"
                  "   beta: 2\n"
                  "alias: *first\n"
                  "merged:\n"
                  "   <<: *first\n"
                  "   beta: 20\n");
   show( @"alpha", [[plist objectForKey:@"alias"] objectForKey:@"alpha"]);
   show( @"beta",  [[plist objectForKey:@"alias"] objectForKey:@"beta"]);
   show( @"m_a", [[plist objectForKey:@"merged"] objectForKey:@"alpha"]);
   show( @"m_b", [[plist objectForKey:@"merged"] objectForKey:@"beta"]);

   plist = parse( @"base1: &b1 { a: 1, b: 2 }\n"
                  "base2: &b2 { b: 20, c: 3 }\n"
                  "merged:\n"
                  "   <<: [ *b1, *b2 ]\n"
                  "   c: 30\n");
   show( @"b1_a", [[plist objectForKey:@"merged"] objectForKey:@"a"]);
   show( @"b1_b", [[plist objectForKey:@"merged"] objectForKey:@"b"]);
   show( @"b2_c", [[plist objectForKey:@"merged"] objectForKey:@"c"]);

   //
   // things the reader deliberately hands back as strings
   //
   mulle_printf( "== stays string\n");
   plist = parse( @"date: 2024-01-02\n"
                  "time: 1:30\n"
                  "binary: !!binary aGVsbG8=\n");
   show( @"date",   [plist objectForKey:@"date"]);
   show( @"time",   [plist objectForKey:@"time"]);
   show( @"binary", [plist objectForKey:@"binary"]);

   //
   // non string scalar keys
   //
   mulle_printf( "== scalar keys\n");
   plist = parse( @"1: one\n"
                  "2: two\n");
   show( @"1", [plist objectForKey:[NSNumber numberWithInt:1]]);
   show( @"2", [plist objectForKey:[NSNumber numberWithInt:2]]);

   //
   // a null key is a scalar and survives as an NSNull key
   //
   plist = parse( @"~: nothing\n");
   mulle_printf( "  null key       %s\n",
                  [plist objectForKey:[NSNull null]] ? "present" : "absent");

   //
   // the root of a document need not be a collection
   //
   mulle_printf( "== root types\n");
   value = [@"just a scalar\n" mulleYAML];
   mulle_printf( "  scalar         %-10s %@\n", typeName( value), value);

   value = [@"- a\n- b\n" mulleYAML];
   mulle_printf( "  sequence       %-10s %@\n", typeName( value), value);

   value = [@"{}\n" mulleYAML];
   mulle_printf( "  empty map      %-10s %@\n", typeName( value), value);

   value = [@"[]\n" mulleYAML];
   mulle_printf( "  empty seq      %-10s %@\n", typeName( value), value);

   //
   // error reporting for a malformed flow collection
   //
   mulle_printf( "== errors\n");
   parser = [MulleYAMLParser parser];
   value  = [parser parseData:[@"[ a, b\n" dataUsingEncoding:NSUTF8StringEncoding]];
   mulle_printf( "  unclosed flow  %s\n", value ? "parsed" : "nil");
   mulle_printf( "  line           %lu\n", (unsigned long) [parser line]);
   mulle_printf( "  problem        %@\n", [parser problem]);

   //
   // a merge key with a bad value must point at the "<<" line
   //
   parser = [MulleYAMLParser parser];
   value  = [parser parseData:[@"a: 1\nmerged:\n   <<: 5\n" dataUsingEncoding:NSUTF8StringEncoding]];
   mulle_printf( "  bad merge      %s\n", value ? "parsed" : "nil");
   mulle_printf( "  line           %lu\n", (unsigned long) [parser line]);
   mulle_printf( "  problem        %@\n", [parser problem]);

   return( 0);
}
