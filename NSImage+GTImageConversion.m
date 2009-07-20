#import "NSImage+GTImageConversion.h"

/* implementation file */
@implementation NSImage (GTImageConversion)
+ (NSImageRep *)_gt_CGImageRepFromCGImage: (CGImageRef)image {
   NSImageRep *rep = nil;

   /* NSCGImageRep is a private AppKit class which, if available, will be more
      trustworthy than drawing the image into a new image rep */
   Class nsCGImageRepClass = objc_lookUpClass("NSCGImageRep");
   if (nsCGImageRepClass && class_getInstanceMethod(nsCGImageRepClass, @selector(initWithCGImage:))) {
      rep = objc_msgSend(nsCGImageRepClass, @selector(alloc));
      rep = objc_msgSend(rep, @selector(initWithCGImage:), image);
      rep = objc_msgSend(rep, @selector(autorelease));
   }

   return rep;
}

+ (NSImage *)gt_imageWithCGImage: (CGImageRef)image {
   if (!image)
      return nil;

   NSImage *result = nil;
   
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
   {
      NSImageRep *rep = [self _gt_CGImageRepFromCGImage: image];
      if (rep) {
         /* wrap the image rep in an NSImage -- the image is released upon method return */
         result = [[NSImage alloc] initWithSize: [rep size]];
         [result addRepresentation: rep];
      } else {
         /* failed to use NSCGImageRep class -- instead, just create the image and draw into it */
         size_t width = CGImageGetWidth(image);
         size_t height = CGImageGetHeight(image);

         result = [[NSImage alloc] initWithSize: NSMakeSize(width, height)];
         [result lockFocus];
         {
            CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
            if (context) {
               /* NOTE: your particular colorimetric needs may require some tweaking */
               CGContextSetInterpolationQuality(context, kCGInterpolationNone);
               CGContextSetRenderingIntent(context, kCGRenderingIntentAbsoluteColorimetric);

               CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), image);
            }
         }
         [result unlockFocus];
      }
   }
   [pool release];
   
   return [result autorelease];
}

@end

