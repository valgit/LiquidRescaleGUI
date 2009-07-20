#import "NSFileManager-Extensions.h"

@implementation NSFileManager(NSFileManager_Extensions)

- (NSString *)nextUniqueNameUsing:(NSString *)templatier withFormat:(NSString *)format appending:(NSString *)append
{
    static int unique = 1;
    NSString *tempName = nil;

    if ([format isEqualToString:@""])
                format = [templatier pathExtension];

    NSLog(@"format is : %@",format);

    tempName =[NSString stringWithFormat:@"%@%@.%@",
                [templatier stringByDeletingPathExtension],append,
                //[templatier pathExtension]];
                format];
                if ([[NSFileManager defaultManager] fileExistsAtPath:tempName]) {
                        do {
                                tempName =[NSString stringWithFormat:@"%@%@_%d.%@",
                                        [templatier stringByDeletingPathExtension],append,unique++,
                                        //[templatier pathExtension]];
                                        format];
            } while ([[NSFileManager defaultManager] fileExistsAtPath:tempName]);
    }
                return tempName;
}

// return a somewhat globally unique filename ...
//
-(NSString*)tempfilename:(NSString *)format;
{
      NSString *tempFilename = NSTemporaryDirectory();
      NSString *tempString = [[NSProcessInfo processInfo] globallyUniqueString];
      tempFilename = [tempFilename stringByAppendingPathComponent:tempString];
      return [[NSString stringWithFormat:@"%@.%@",tempFilename,format] retain];
}

//
// Temporary Directory stuff: useful code.
//

BOOL directoryOK(NSString *path)
{
    BOOL isDirectory;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
        NSDictionary *dict = [NSDictionary dictionaryWithObject:
            [NSNumber numberWithUnsignedLong:0777]
                               forKey:NSFilePosixPermissions];
        if (![fileManager createDirectoryAtPath:path attributes:dict])
            return NO;
    }
    return YES;
}

NSString* existingPath(NSString *path)
{
    while (path && ![path isEqualToString:@""]
                   && ![[NSFileManager defaultManager] fileExistsAtPath:path])
        path = [path stringByDeletingLastPathComponent];
    return path;
}

NSArray *directoriesToAdd(NSString *path, NSString *existing)
{
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:4];
    if (path != nil && existing != nil) {
        while (![path isEqualToString:existing]) {
            [a insertObject:[path lastPathComponent] atIndex:0];
            path = [path stringByDeletingLastPathComponent];
        }
    }
    return a;
}

// this will go up the path until it finds an existing directory
// and will add each subpath and return YES if succeeds, NO if fails:

- (BOOL)createWritableDirectory:(NSString *)path
{
    BOOL isDirectory;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory]
        && isDirectory && [fileManager isWritableFileAtPath:path])
        return YES; // no work to do
    else {
        NSString *existing = existingPath(path);
        NSArray *dirsToAdd = directoriesToAdd(path,existing);
        int i;
        BOOL good = YES;
        for (i = 0; i < [dirsToAdd count]; i++) {
            existing = [existing stringByAppendingPathComponent:
                [dirsToAdd objectAtIndex:i]];
            if (!directoryOK(existing)) {
                good = NO;
                break;
            }
        }
        return good;
    }
}

- (NSString *)temporaryDirectory
{
    NSString *tempDir =[[NSTemporaryDirectory()
        stringByAppendingPathComponent:
        [[NSProcessInfo processInfo] processName]]
        stringByAppendingPathComponent:NSUserName()];

    if (! [self createWritableDirectory:tempDir]) {
        NSLog(@"Couldn't create %@, using %@",tempDir,
                          NSTemporaryDirectory());
        tempDir = NSTemporaryDirectory();
    }
    return tempDir;
}

@end

