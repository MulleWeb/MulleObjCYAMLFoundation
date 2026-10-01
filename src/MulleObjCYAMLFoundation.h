#import "import.h"

#include <stdint.h>

/*
 *  (c) <|YEAR|> nat <|ORGANIZATION|>
 *
 *  version:  major, minor, patch
 */
#define MULLE_OBJC_YAML_FOUNDATION_VERSION  ((0UL << 20) | (0 << 8) | 1)


static inline unsigned int   MulleObjCYAMLFoundation_get_version_major( void)
{
   return( MULLE_OBJC_YAML_FOUNDATION_VERSION >> 20);
}


static inline unsigned int   MulleObjCYAMLFoundation_get_version_minor( void)
{
   return( (MULLE_OBJC_YAML_FOUNDATION_VERSION >> 8) & 0xFFF);
}


static inline unsigned int   MulleObjCYAMLFoundation_get_version_patch( void)
{
   return( MULLE_OBJC_YAML_FOUNDATION_VERSION & 0xFF);
}


MULLE_OBJC_PLIST_YAML_FOUNDATION_GLOBAL
uint32_t   MulleObjCYAMLFoundation_get_version( void);

/*
   Add your library headers here for exposure to library
   consumers.
*/
#import "MulleYAMLParser.h"
#import "MulleYAMLWriter.h"

#import "MulleObjCDeps+MulleObjCYAMLFoundation.h"


#ifdef __has_include
# if __has_include( "_MulleObjCYAMLFoundation-versioncheck.h")
#  include "_MulleObjCYAMLFoundation-versioncheck.h"
# endif
#endif
