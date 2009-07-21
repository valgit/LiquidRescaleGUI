/*
 *
 */

#import "ImageDisplayView.h"

@implementation ImageDisplayView

- (id)initWithFrame:(NSRect)frame;
{
   self = [super initWithFrame:frame];
   if (self) {
	// Initialization code here.
	 _bgColor = [[NSColor blackColor] retain];
   }
   return self;
}

- (void)dealloc;
{
	[_image release];
	[_bgColor release];
	[super dealloc];
}

- (void) setImage:(NSImage*)image
{
    NSImage *temp = [image retain];

    [_image release];
    _image = temp;
    [_image setScalesWhenResized:YES];
    [self setNeedsDisplay:YES];
}

- (void)setBackgroundColor:(NSColor*)color
{
    NSColor *temp = [color retain];

    [_bgColor release];
    _bgColor = temp;
    [self setNeedsDisplay:YES];
}

- (NSImage*)image
{
    return _image;
}

- (NSColor*)backgroundColor
{
    return _bgColor;
}


- (void)drawRect:(NSRect)rect;
{
     NSRect bounds = [self bounds];

    //NSLog(@"%s",__PRETTY_FUNCTION__);
    // fill the background 
    [_bgColor set];
    NSRectFill(bounds);

#if 0
	// border ?
	NSBezierPath * path = [NSBezierPath bezierPathWithRect:bounds]; 
	[path setLineWidth:3]; 
	[[NSColor whiteColor] set];
	 [path stroke]; 
#endif

    // draw the image !
    if (_image) {
	NSSize thumbsize = [_image size];
    NSLog(@"%s thumb (%f,%f)",__PRETTY_FUNCTION__,thumbsize.width,thumbsize.height);
#if 0
	//[_image drawAtPoint:NSZeroPoint 
	//	fromRect:NSMakeRect(0,0, thumbsize.width,thumbsize.height) 
	//	operation:NSCompositeSourceOver fraction:1.0];
	//[_image setFlipped:YES]; 
	[_image drawInRect: bounds  
		fromRect: NSZeroRect 
		operation: NSCompositeSourceOver fraction: 1.0]; 

	//[_image drawInRect:NSMakeRect( 0, 0, rect.size.width,rect.size.height)
				 //fromRect:NSMakeRect(0,0, thumbsize.width,thumbsize.height)
	//			 fromRect:NSZeroRect
	//			operation:NSCompositeSourceOver
	//			 fraction:1.0];
#else
        [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	[_image setCacheMode: NSImageCacheNever];
        
        NSSize viewSize  = [self bounds].size;
        NSSize imageSize = [_image size];
	double imageScale = viewSize.width/thumbsize.width;
        NSAffineTransform* at = [NSAffineTransform transform];
        //[at scaleBy:imageScale];
        imageSize = [at transformSize:imageSize];
	NSLog(@"%s thumb (%f,%f)",__PRETTY_FUNCTION__,imageSize.width,imageSize.height);

        NSPoint viewCenter;
        viewCenter.x = viewSize.width  * 0.50;
        viewCenter.y = viewSize.height * 0.50;

        NSPoint imageOrigin = viewCenter;
        imageOrigin.x -= imageSize.width  * 0.50;
        imageOrigin.y -= imageSize.height * 0.50;

        NSRect destRect;
        destRect.origin = imageOrigin;
        destRect.size = imageSize;
        
        [_image drawInRect:destRect
                                fromRect:NSMakeRect(0,0, imageSize.width,imageSize.height)
                                operation:NSCompositeSourceOver
                                fraction:1.0];

#endif
  }
}

#pragma mark  <event handling>

- (BOOL) acceptsFirstResponder
{
        return YES;
}

- (BOOL) resignFirstResponder
{
        [self setNeedsDisplay:YES];
        return YES;
}

- (BOOL) becomeFirstResponder
{
        [self setNeedsDisplay:YES];
        return YES;
}

#pragma <Action & UI>

- (void)mouseDown:(NSEvent*)event
{
  //      NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (void)mouseMoved: (NSEvent*)event
{
 //       NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (void)mouseUp:(NSEvent *)event
{
//        NSLog(@"%s",__PRETTY_FUNCTION__);
	NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
}

- (void)mouseDragged:(NSEvent*)event
{
//        NSLog(@"%s",__PRETTY_FUNCTION__);
#if 0
    var newPoint = [event locationInWindow];
    newPoint.x -= mouseDownPoint.x;
    newPoint.y -= mouseDownPoint.y;
    [self setFrameOrigin:newPoint];
#endif
	NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
}

@end

