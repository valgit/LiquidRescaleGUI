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
	_displayAfter = NO;
	_beforeImage = nil;
	_afterImage = nil;
	_maskImage = nil;
   }
   return self;
}

- (void)dealloc;
{
	[_beforeImage release];
	[_afterImage release];
	[_bgColor release];
	[super dealloc];
}

- (void) setDelegate:(id)del;
{
	delegate = del;	
}

- (id) delegate;
{
	return delegate;
}

- (void) setBeforeImage:(NSImage*)image
{
    NSImage *temp = [image retain];

    [_beforeImage release];
    _beforeImage = temp;
    [_beforeImage setScalesWhenResized:YES];
    [self setNeedsDisplay:YES];
}

- (void) setAfterImage:(NSImage*)image
{
    NSImage *temp = [image retain];

    [_afterImage release];
    _afterImage = temp;
    [_afterImage setScalesWhenResized:YES];
    [self setNeedsDisplay:YES];
}

- (void)setDisplayAfter:(BOOL)state;
{
	if (_displayAfter != state) {
		_displayAfter = state;	
	}
}

- (void)reloadImage;
{
	[self setNeedsDisplay:YES];
}

- (void) setMaskImage:(NSImage*)image
{
    NSImage *temp = [image retain];

    [_maskImage release];
    _maskImage = temp;
    [_maskImage setScalesWhenResized:YES];
    [self setNeedsDisplay:YES];
}

- (void)setBackgroundColor:(NSColor*)color
{
    NSColor *temp = [color retain];

    [_bgColor release];
    _bgColor = temp;
    [self setNeedsDisplay:YES];
}

- (NSImage*)beforeImage
{
    return _beforeImage;
}

- (NSImage*)afterImage
{
    return _afterImage;
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
    NSImage* _image;
    if (_displayAfter)	{
	_image = [self afterImage];
    } else
	_image = [self beforeImage];
	
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

	if (_maskImage) {
		NSSize imageSize = [_maskImage size];
		NSLog(@"%s image mask (%f,%f)",__PRETTY_FUNCTION__,
			imageSize.width,imageSize.height);
		[_maskImage drawInRect:destRect
                                fromRect:NSMakeRect(0,0, imageSize.width,imageSize.height)
                                operation:NSCompositeSourceOver
                                fraction:1.0];
	}
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
	NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
	double pressure = [event pressure];
	if(([event type] == NSTabletPoint) ||
	   ([event subtype] == NSTabletPointEventSubtype)) {
		int mask = [event buttonMask];
		NSLog(@"%s -> tablette %x",__PRETTY_FUNCTION__,mask);
		
		if (mask & NSPenTipMask)
			NSLog(@"%s -> pentip",__PRETTY_FUNCTION__);
		if (mask & NSPenLowerSideMask)
			NSLog(@"%s -> NSPenLowerSide",__PRETTY_FUNCTION__);
		if (mask & NSPenUpperSideMask)
			NSLog(@"%s -> NSPenUpperSide",__PRETTY_FUNCTION__);
	}

//        NSLog(@"%s -> (%f,%f) pres: %f",__PRETTY_FUNCTION__,loc.x,loc.y,pressure);
	if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewMouseDown:inView:)]) {
		[delegate imageDisplayViewMouseDown:event inView:self];
	}
}

- (void)mouseMoved: (NSEvent*)event
{
        //NSLog(@"%s",__PRETTY_FUNCTION__);
	if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewMouseMoved:inView:)]) {
		[delegate imageDisplayViewMouseMoved:event inView:self];
	}
}

- (void)mouseUp:(NSEvent *)event
{
  //      NSLog(@"%s",__PRETTY_FUNCTION__);
	NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
	if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewMouseUp:inView:)]) {
		[delegate imageDisplayViewMouseUp:event inView:self];
	}
}

- (void)mouseDragged:(NSEvent*)event
{
    //    NSLog(@"%s",__PRETTY_FUNCTION__);
#if 0
    var newPoint = [event locationInWindow];
    newPoint.x -= mouseDownPoint.x;
    newPoint.y -= mouseDownPoint.y;
    [self setFrameOrigin:newPoint];
#endif
	double pressure = [event pressure];
	if(([event type] == NSTabletPoint) ||
	   ([event subtype] == NSTabletPointEventSubtype)) {
		int mask = [event buttonMask];
		NSLog(@"%s -> tablette %x",__PRETTY_FUNCTION__,mask);
		
		if (mask & NSPenTipMask)
			NSLog(@"%s -> pentip",__PRETTY_FUNCTION__);
		if (mask & NSPenLowerSideMask)
			NSLog(@"%s -> NSPenLowerSide",__PRETTY_FUNCTION__);
		if (mask & NSPenUpperSideMask)
			NSLog(@"%s -> NSPenUpperSide",__PRETTY_FUNCTION__);
	}

	NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"%s -> (%f,%f) pres: %f",__PRETTY_FUNCTION__,loc.x,loc.y,pressure);
	if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewMouseDragged:inView:)]) {
		[delegate imageDisplayViewMouseDragged:event inView:self];
	}
}

#pragma mark -
#pragma mark tablet

- (void)tabletProximity:(NSEvent *)tabletEvent
{
    NSLog(@"%s capa: %d",__PRETTY_FUNCTION__,[tabletEvent capabilityMask]);
	//[theEvent isEnteringProximity]
    [super tabletProximity:tabletEvent];
}

- (void)tabletPoint:(NSEvent *)tabletEvent
{
    NSLog(@"%s",__PRETTY_FUNCTION__);
    [super tabletPoint:tabletEvent];
}
@end

