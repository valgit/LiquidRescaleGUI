#import <Cocoa/Cocoa.h>

@interface NSFileManager(NSFileManager_Extensions)


- (NSString *)nextUniqueNameUsing:(NSString *)templatier withFormat:(NSString *)format appending:(NSString *)append;
-(NSString*)tempfilename:(NSString *)format;

- (BOOL)createWritableDirectory:(NSString *)path;
- (NSString *)temporaryDirectory;

@end


