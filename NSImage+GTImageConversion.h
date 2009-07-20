#import <Cocoa/Cocoa.h>

/* header file */
@interface NSImage (GTImageConversion)
+ (NSImage *)gt_imageWithCGImage: (CGImageRef)image;
@end

