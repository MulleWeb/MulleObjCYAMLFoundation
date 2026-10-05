# MulleObjCYAMLFoundation Library Documentation for AI
<!-- Keywords: yaml, parser, writer, property-list, serialization, objc, plist -->

## 1. Introduction & Purpose

MulleObjCYAMLFoundation adds YAML as a property list format to mulle-objc.
It solves the problem of reading and writing YAML configuration (frontmatter,
`_config.yml`-style files) using the same `NSDictionary` / `NSArray` /
`NSString` / `NSNumber` / `NSNull` object graph that the rest of Foundation
already speaks.

Key features:

- `MulleYAMLParser` reads YAML into a property list. It is built on
  [libyaml] and resolves plain scalars the way Ruby's Psych does: `yes` is a
  boolean, `08` is a string, `1.20` is a float.
- `MulleYAMLWriter` writes a property list back out as block style YAML that
  round trips through the parser to an equal property list.
- `NSPropertyListSerialization( YAML )` registers `MullePropertyListYAMLFormat`
  as both a detectable/readable and a printable format, and installs a format
  detector that recognises a `key:` mapping, a block sequence or a `---`
  document marker.
- `NSString( MulleYAMLParser )` offers a one-line `-mulleYAML` shortcut.

The library is a thin, self-contained add-on to
`MulleFoundationBase`; it depends on libyaml for the actual YAML tokenizing.

## 2. Key Concepts & Design Philosophy

- **YAML as a plist format, not a data model of its own.** There is no custom
  YAML node class. A parsed document is exactly a plist; anything Foundation
  can do with a plist applies.
- **Psych-compatible implicit typing.** libyaml is the same engine Ruby's
  Psych uses, so the core schema resolution matches Jekyll: booleans
  (`yes`/`no`/`on`/`off`), integers (decimal, `0x`, `0b`, `0` octal,
  `1_000`), floats (`1.20`, `.inf`), and `~`/`null` for null. Quoted scalars
  are always strings.
- **Strings win when quoted.** The writer double quotes any string the reader
  would otherwise resolve to a number, boolean, null or structure, so type is
  preserved across a round trip.
- **Detection is heuristic, forcing is exact.** YAML has no magic bytes. A
  flow collection (`[...]`, `{...}`) is indistinguishable from JSON and is
  deliberately not claimed by the detector; force the format when in doubt.
- **Merge keys are honoured.** `<<` merge keys resolve; a mapping's own keys
  win over merged ones. A bad merge value is a parse error located at the
  `<<` line.
- **Errors are data, not just stderr.** `-parseData:` returns `nil` and the
  parser remembers `-problem`, `-line` and `-column`.

## 3. Core API & Data Structures

### 3.1. `MulleYAMLParser.h`

#### `@interface MulleYAMLParser : NSObject`

- **Purpose:** Reads a YAML document and produces a property list.
- **Lifecycle:**
  - `+ (instancetype) parser;` — a fresh parser, one per document.
  - `- (id) parseData:(NSData *) data;` — parse the data. On failure returns
    `nil` and remembers where it went wrong in `-problem`, `-line` and
    `-column`.
- **Properties:**
  - `@property( assign) BOOL nilOnEmptyDocument;` — by default a document with
    no node (empty file, or just `---`) yields an empty `NSDictionary`. Set
    this to get `nil` instead.
  - `@property( readonly, assign) NSUInteger line;` — 1 based, 0 if unknown.
  - `@property( readonly, assign) NSUInteger column;` — 1 based, 0 if unknown.
  - `@property( readonly, retain) NSString *problem;` — human readable
    diagnostic, e.g. `line 2, column 4: mapping values are not allowed in this
    context`.

Reader behaviour worth knowing:

- The document root may be a mapping, a sequence or a scalar.
- `!!timestamp`, the sexagesimal numeric forms (`1:30`) and `!!binary` are
  returned as strings, not converted.
- A mapping key that is itself a collection is refused, because such a key
  cannot be a dictionary key.
- Known quirk: an explicit tag is honoured, except that a plain (unquoted)
  `!!str` is still resolved by the core schema. So `!!str 123` parses as the
  number `123`, while `!!str "123"` parses as the string `123`.

#### `@interface NSString( MulleYAMLParser )`

- `- (id) mulleYAML;` — parses the receiver as YAML and returns a property
  list. Shortcut for a `MulleYAMLParser` round.

### 3.2. `MulleYAMLWriter.h`

#### `@interface MulleYAMLWriter : NSObject`

- **Purpose:** Turns a property list into a block style YAML document.
- **Lifecycle:**
  - `+ (instancetype) writer;` — a fresh writer, one per document.
  - `+ (NSData *) dataWithPropertyList:(id) plist;` — convenience, default
    settings, UTF-8 `NSData`.
  - `+ (NSString *) stringWithPropertyList:(id) plist;` — convenience, default
    settings.
  - `- (NSData *) dataFromPropertyList:(id) plist;`
  - `- (NSString *) stringFromPropertyList:(id) plist;`
  - `- (void) writePropertyList:(id) plist toStream:(id <MulleObjCOutputStream>) stream;`
- **Properties:**
  - `@property( assign) NSUInteger indentWidth;` — spaces per nesting level,
    `2` by default.
  - `@property( assign) BOOL sortsKeys;` — dictionary keys are printed sorted
    by default (`YES`), which makes output deterministic.

Writer behaviour worth knowing:

- Empty containers are written as flow collections: `{}` and `[]`.
- `inf`, `-inf` and `nan` get the YAML spellings `.inf`, `-.inf`, `.nan`.
- The framework canonicalizes an integral double, so `1.0` is stored and
  written as the integer `1`.
- A `nil` plist writes an empty string.

#### `@interface NSObject( MulleYAMLWriter )`

- `- (void) mullePrintYAMLToStream:(id <MulleObjCOutputStream>) stream;` — the
  print entry point `NSPropertyListSerialization` uses for
  `MullePropertyListYAMLFormat`, installed in the `+load` of
  `NSPropertyListSerialization( YAML)`.

### 3.3. `NSPropertyListSerialization( YAML )`

Declared and installed in `NSPropertyListSerialization+YAML.m` (no public
header). At `+load` it calls
`+mulleAddFormatDetector:`, `+mulleAddParserClass:method:forPropertyListFormat:`
and `+mulleAddPrintMethod:forPropertyListFormat:` to register
`MullePropertyListYAMLFormat` as readable and printable.

- `+ (NSPropertyListFormat) mulleDetectYAMLFormat:(NSData *) data;` — returns
  `MullePropertyListYAMLFormat` when the data begins with a `---` marker, a
  `%` directive, a block sequence (`- `) or a plain `key:` mapping; returns
  `0` (no claim) for a flow collection or any other format.

Reading and writing then go through the standard plist entry points, as shown
in the tests:

```objc
// forced read
format = MullePropertyListYAMLFormat;
plist  = [NSPropertyListSerialization mullePropertyListFromData:data
                                               mutabilityOption:0
                                                         format:&format
                                                   formatOption:MullePropertyListFormatOptionForce];

// write
data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                   format:MullePropertyListYAMLFormat
                                                  options:0
                                                    error:&error];
```

`MullePropertyListFormatOptionForce` is required for a flow collection, since
the detector does not claim it.

### 3.4. `MulleObjCYAMLFoundation.h`

- `#define MULLE_OBJC_YAML_FOUNDATION_VERSION` — packed `major << 20 | minor << 8 | patch`.
- `static inline unsigned int MulleObjCYAMLFoundation_get_version_major( void);`
- `static inline unsigned int MulleObjCYAMLFoundation_get_version_minor( void);`
- `static inline unsigned int MulleObjCYAMLFoundation_get_version_patch( void);`
- `uint32_t MulleObjCYAMLFoundation_get_version( void);`

This header also imports `MulleYAMLParser.h`, `MulleYAMLWriter.h` and the
dependency declaration header, so importing `MulleObjCYAMLFoundation.h` is the
normal way to pull in the whole library.

### 3.5. `MulleObjCDeps+MulleObjCYAMLFoundation.h`

- `@interface MulleObjCDeps( MulleObjCYAMLFoundation )`
  - `+ (struct _mulle_objc_dependency *) dependencies;` — required to be public
    so other libraries that depend on this library can declare their load in
    their `MulleObjcLoader` class.

## 4. Performance Characteristics

- **Parsing** is a single libyaml pass over the data, O(n) in document size,
  with the property list built as nodes are completed.
- **Writing** builds an array of lines per container and concatenates them,
  O(n) in output size; sorting dictionary keys is O(k log k) per mapping.
- **Memory:** no custom allocator; standard Foundation object lifetimes apply.
- **Thread safety:** `MulleYAMLParser` and `MulleYAMLWriter` instances are
  stateful and not thread-safe. Use one instance per thread/document, which is
  what the `+parser` / `+writer` factory methods are for. There is no shared
  global mutable state after the one-time `+load` registration.

## 5. AI Usage Recommendations & Patterns

- **Best practices:**
  - Get a fresh parser/writer with `+[MulleYAMLParser parser]` /
    `+[MulleYAMLWriter writer]`; do not share instances across documents.
  - Prefer the `MulleYAMLWriter` convenience class methods when the default
    `indentWidth` and `sortsKeys` are acceptable.
  - Check `-problem` (and `-line` / `-column`) whenever `-parseData:` returns
    `nil`; do not rely on stderr.
  - Force `MullePropertyListYAMLFormat` whenever the document could be a flow
    collection.
- **Common pitfalls:**
  - The format detector does not claim flow collections; they can be mistaken
    for JSON. Force the format.
  - A plain `!!str 123` is still resolved as a number. Quote it
    (`!!str "123"`) to keep it a string.
  - `nilOnEmptyDocument` is `NO` by default, so an empty document is an empty
    dictionary, not `nil`.
  - Do not touch the `_indentWidth` / `_sortsKeys` instance variables; use the
    properties.
- **Idiomatic usage:** use the plist serialization API when you want format
  detection/forcing and the classes directly when you only read or only write
  YAML.

## 6. Integration Examples

### Example 1: Reading YAML with MulleYAMLParser

```objc
MulleYAMLParser   *parser;
NSDictionary      *plist;
NSData            *data;

data   = [yaml dataUsingEncoding:NSUTF8StringEncoding];
parser = [MulleYAMLParser parser];
plist  = [parser parseData:data];
if( ! plist)
{
   mulle_printf( "%@\n", [parser problem]);
   return( 1);
}
mulle_printf( "%@\n", [plist objectForKey:@"title"]);
```

### Example 2: The NSString shortcut

```objc
id   plist;

plist = [@"title: My Post\ntags:\n   - one\n   - two\n" mulleYAML];
mulle_printf( "%@\n", [plist objectForKey:@"tags"]);
```

### Example 3: Writing YAML with MulleYAMLWriter

```objc
MulleYAMLWriter   *writer;
NSData            *data;
NSString          *text;
id                plist;

plist  = [NSDictionary dictionaryWithObjectsAndKeys:
             @"My Post",                       @"title",
             [NSNumber numberWithBool:YES],    @"published",
             [NSNumber numberWithInt:42],      @"count",
             nil];
writer = [MulleYAMLWriter writer];
[writer setIndentWidth:4];
data   = [writer dataFromPropertyList:plist];
text   = [[[NSString alloc] initWithData:data
                                encoding:NSUTF8StringEncoding] autorelease];
mulle_printf( "%@", text);
```

### Example 4: Detection and forcing through the plist API

```objc
NSPropertyListFormat   format;
NSData                 *data;
id                     plist;

data   = [yaml dataUsingEncoding:NSUTF8StringEncoding];
format = 0;
plist  = [NSPropertyListSerialization propertyListWithData:data
                                                   options:0
                                                    format:&format
                                                     error:NULL];
// flow collections need an explicit format
format = MullePropertyListYAMLFormat;
plist  = [NSPropertyListSerialization mullePropertyListFromData:data
                                               mutabilityOption:0
                                                         format:&format
                                                   formatOption:MullePropertyListFormatOptionForce];
```

### Example 5: Round trip

```objc
MulleYAMLParser   *parser;
NSData            *data;
id                parsed;

data   = [MulleYAMLWriter dataWithPropertyList:plist];
parser = [MulleYAMLParser parser];
parsed = [parser parseData:data];
if( [parsed isEqual:plist])
   mulle_printf( "round trip ok\n");
```

## 7. Dependencies

Direct `mulle-sde` library dependencies (from `.mulle/etc/sourcetree/config`):

- `libyaml` — YAML tokenizer/parser engine (build: no-all-load, no-import).
- `MulleFoundationBase` — Foundation base, provides
  `NSPropertyListSerialization`, `MulleObjCOutputStream` and the plist format
  machinery this library plugs into.
- `mulle-objc-tools` — build-only (`no-link`, `no-header`), not a runtime
  dependency.
