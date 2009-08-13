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
	_selectionRect = NSMakeRect(0,0,frame.size.width,frame.size.height);
	_zoom = 100;
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

- (void) setSelectionRectOrigin:(NSPoint)origin;
{
	_selectionRect.origin.x = origin.x;
	_selectionRect.origin.y = origin.y;
	[self setNeedsDisplay:YES];
}

- (double)magnification;
{
	return _zoom;
}

- (void)setMagnification:(double)zoom;
{
	_zoom = zoom;
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
		[self setNeedsDisplay:YES];
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
	
    // draw the image !
    NSImage* _image;
    if (_displayAfter)	{
		_image = [self afterImage];
    } else
		_image = [self beforeImage];
	
    if (_image) {
		//NSSize thumbsize = [_image size];
		//NSLog(@"%s thumb (%f,%f)",__PRETTY_FUNCTION__,thumbsize.width,thumbsize.height);
        [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		//[_image setCacheMode: NSImageCacheNever];
        
        NSSize viewSize  = bounds.size;
        NSSize imageSize = [_image size];

        NSRect destRect;
        //destRect.origin = imageOrigin;
		destRect.origin.x = 0;
		destRect.origin.y = 0;
        destRect.size = imageSize;
       	/*	 
		 NSLog(@"%s start at: (%f,%f) \n\tdest: (%f,%f) \n\tfrom: (%f,%f)",__PRETTY_FUNCTION__,
		 _selectionRect.origin.x,_selectionRect.origin.y,
		 destRect.size.width,destRect.size.height,
		 imageSize.width,imageSize.height);
		 */
        [_image drawInRect:bounds
			  fromRect:NSMakeRect(_selectionRect.origin.x,_selectionRect.origin.y,
						  viewSize.width * _zoom,viewSize.height * _zoom)
				 operation:NSCompositeSourceOver
				  fraction:1.0];
		
		if (_maskImage) {
			[_maskImage drawInRect:bounds
						  fromRect:NSMakeRect(_selectionRect.origin.x,_selectionRect.origin.y,
											  viewSize.width * _zoom,viewSize.height * _zoom)
						 operation:NSCompositeSourceAtop//NSCompositeSourceOver
						  fraction:1.0];
		}
		
		// draw some frame
		NSRect imgframe = NSMakeRect(-_selectionRect.origin.x / _zoom , -_selectionRect.origin.y / _zoom,imageSize.width / _zoom, imageSize.height / _zoom);
		NSBezierPath * path = [NSBezierPath bezierPathWithRect:imgframe]; 
		[path setLineWidth:3]; 
		[[NSColor whiteColor] set];
		[path stroke]; 
	
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
	_grabOrigin = [event locationInWindow];
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
	//NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
	if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewMouseUp:inView:)]) {
		[delegate imageDisplayViewMouseUp:event inView:self];
	}
}

- (void)mouseDragged:(NSEvent*)event
{
    //    NSLog(@"%s",__PRETTY_FUNCTION__);
	if (([event modifierFlags] & NSCommandKeyMask) != 0 ) { 
		//NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
		NSPoint mousePoint;
		mousePoint = [event locationInWindow];
		
		float deltaX, deltaY;
		deltaX = mousePoint.x - _grabOrigin.x;
		deltaY = - (mousePoint.y - _grabOrigin.y);
		
		NSLog(@"%s need panning (%f,%f)",__PRETTY_FUNCTION__,deltaX,deltaY);
		//loc.x = -loc.x;
		//loc.y = -loc.y; // mirror
		mousePoint.x = _selectionRect.origin.x + deltaX;
		mousePoint.y = _selectionRect.origin.y + deltaY;
		[self setSelectionRectOrigin:mousePoint];
		return ;
	}
	if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewMouseDragged:inView:)]) {
		[delegate imageDisplayViewMouseDragged:event inView:self];
	}
}

#pragma mark -
#pragma mark tablet

- (void)tabletProximity:(NSEvent *)tabletEvent
{
    if (delegate && [delegate respondsToSelector:@selector(imageDisplayViewtabletProximity:inView:)]) {
		[delegate imageDisplayViewtabletProximity:tabletEvent inView:self];
	}
    [super tabletProximity:tabletEvent];
}

- (void)tabletPoint:(NSEvent *)tabletEvent
{
    NSLog(@"%s",__PRETTY_FUNCTION__);
    [super tabletPoint:tabletEvent];
}

#pragma mark -
#pragma mark keyboard

- (void)keyDown:(NSEvent *)event
{
	unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
	//short kc = [event keyCode];
	if (key == ' ') {
		NSLog(@"%s switch display",__PRETTY_FUNCTION__);
	}
	[super keyDown:event];
}

@end

