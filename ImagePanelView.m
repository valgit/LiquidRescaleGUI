/*
 *
 */

#import "ImagePanelView.h"

@implementation ImagePanelView

- (id)initWithFrame:(NSRect)frame;
{
   self = [super initWithFrame:frame];
   if (self) {
	// Initialization code here.
	[self setAnchor:NSZeroPoint];
	[self setSelSize:NSMakeSize(100,100)];
	_scale = 0.;
	_bgColor = [[NSColor blackColor] retain];
   }
   return self;
}

-(void)dealloc;
{
	[_bgColor release];
	[super dealloc];
}

- (void)setBackgroundColor:(NSColor*)color
{
    NSColor *temp = [color retain];

    [_bgColor release];
    _bgColor = temp;
    [self setNeedsDisplay:YES];
}

- (NSColor*)backgroundColor
{
    return _bgColor;
}

- (void)reloadImage;
{
	[self selectionDidChange];
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect;
{
     NSRect bounds = [self bounds];

    //NSLog(@"%s",__PRETTY_FUNCTION__);
    // fill the background
    [_bgColor set];
    NSRectFill(bounds);

    // draw the image !
    if (dataSource && [dataSource respondsToSelector:@selector(imagePanelViewImageThumbnail:withSize:)]) {
		if (_scale == 0.) {
			  if (dataSource && [dataSource respondsToSelector:@selector(imagePanelViewImageSize:)]) {
				NSSize datasize = [dataSource imagePanelViewImageSize:self];
				[self setImageScale:datasize];
			}
		}
		NSImage *thumb = [dataSource imagePanelViewImageThumbnail:self withSize:_thumbsize];
		NSSize thumbsize = [thumb size];
        NSLog(@"%s draw (%f,%f)",__PRETTY_FUNCTION__,_thumbsize.width,_thumbsize.height);
		[thumb drawInRect:NSMakeRect( 0, 0, _thumbsize.width,_thumbsize.height)
				 fromRect:NSMakeRect(0,0, thumbsize.width,thumbsize.height)
				operation:NSCompositeSourceOver
				 fraction:1.0];
    }

    // display the cell...
    NSRect selection = NSMakeRect(_anchor.x,_anchor.y,_size.width,_size.height);
    if ( NSEqualRects( selection, NSZeroRect ) == NO) {
        //NSLog(@"%s draw sel",__PRETTY_FUNCTION__);
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.20] set];
        [NSBezierPath fillRect:selection];
        [[NSColor whiteColor] set];
        [NSBezierPath strokeRect:selection];
    }

}

#pragma mark < Accessors >

- (NSPoint)anchor;
{
	// note : _anchor is in view coord...
	// need to calc in image coord ...
	NSPoint realpt = NSMakePoint(_anchor.x*_scale,_anchor.y*_scale);	
	return realpt;
}

- (void)setAnchor:(NSPoint)point;
{
	_anchor.x = point.x;
	_anchor.y = point.y;
}

- (NSSize)selSize;
{
	return _size;
}

- (void)setSelSize:(NSSize)size;
{
        NSLog(@"%s %f %f",__PRETTY_FUNCTION__,size.width,size.height);
	// size is in image coord...
	// need to calc in view coord !
	if (_scale != 0) {
		_size.height = size.height/_scale;
		_size.width = size.width/_scale;
	} else {
		_size.height = size.height;
		_size.width = size.width;
	}	
#if 0
        if (dataSource && [dataSource respondsToSelector:@selector(imagePanelViewImageSize:)]) {
		NSSize datasize = [dataSource imagePanelViewImageSize:self];
		[self setImageScale:datasize];
	} else 
		[self setImageScale:NSMakeSize(1.0,1.0)];
#endif
	[self selectionDidChange];
	[self setNeedsDisplay: YES];
}

- (void)setImageScale:(NSSize)size;
{
	NSRect view = [self frame];
	NSSize fsize = view.size;
	float nw,nh;

	NSLog(@"%s (%f,%f) -> (%f,%f)",__PRETTY_FUNCTION__,
		size.width,size.height,
		fsize.width,fsize.height);
	if (size.width>fsize.width || size.height>fsize.height) {
		float wr, hr;

		// ratios
		wr = size.width/fsize.width;
		hr = size.height/fsize.height;

		if (wr>hr) { // landscape
		    _scale = wr;
		    nw = fsize.width;
		    nh = size.height/wr;
		} else { // portrait
			_scale = hr;
		    nh = fsize.height;
		    nw = size.width/hr;
		}
		_thumbsize = NSMakeSize(nw,nh);
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

- (void) selectionDidChange;
{
        if (delegate && [delegate respondsToSelector:@selector(imagePanelViewSelectionDidChange:)]) {
                [delegate imagePanelViewSelectionDidChange:self];
        }
	[self setNeedsDisplay: YES];
}

#pragma mark <Delegate and Data Source Handling>
- (void) setDataSource:(id)source
{
        NSLog(@"%s",__PRETTY_FUNCTION__);
        //[dataSource release];
        //dataSource = [source retain];
        dataSource = source;

        if (dataSource && [dataSource respondsToSelector:@selector(imagePanelViewImageSize:)]) {
		NSSize datasize = [dataSource imagePanelViewImageSize:self];
		[self setImageScale:datasize];
	} else 
		[self setImageScale:NSMakeSize(1.0,1.0)];
	[self selectionDidChange];
}

- (void) setDelegate:(id)del
{
//        [delegate release];
//        delegate = [del retain];
        delegate = del;
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
	_anchor = NSMakePoint(loc.x - _size.width*.5, loc.y - _size.height*.5);
	if (_anchor.x < 0)
		_anchor.x = 0;
	if (_anchor.y < 0)
		_anchor.y = 0;

	[self selectionDidChange];
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
	_anchor = NSMakePoint(loc.x - _size.width*.5, loc.y - _size.height*.5);
	if (_anchor.x < 0)
		_anchor.x = 0;
	if (_anchor.y < 0)
		_anchor.y = 0;

	[self selectionDidChange];
}

@end

