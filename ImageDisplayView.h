/*
 *
 */

#import <Cocoa/Cocoa.h>

@interface ImageDisplayView : NSView
{
	IBOutlet id delegate;

	NSImage* _beforeImage;
	NSImage* _afterImage;

	NSImage* _maskImage;

	NSColor *_bgColor;

	BOOL _displayAfter;
	NSRect _selectionRect;
}

- (id)initWithFrame:(NSRect)frame;

-(void)setBeforeImage:(NSImage*)image;
- (NSImage*)beforeImage;
-(void)setAfterImage:(NSImage*)image;
- (NSImage*)afterImage;
- (void)reloadImage;

- (void) setMaskImage:(NSImage*)image;
- (void)setDisplayAfter:(BOOL)state;

- (void)setBackgroundColor:(NSColor*)color;
- (NSColor*)backgroundColor;

- (void) setDelegate:(id)del;
- (id) delegate;

- (void) setSelectionRectOrigin:(NSPoint)origin;

@end

@interface  ImageDisplayView (delegate)

- (void) imageDisplayViewMouseDown:(NSEvent*)event inView:(NSView*)view;
- (void) imageDisplayViewMouseMoved: (NSEvent*)event inView:(NSView*)view;
- (void) imageDisplayViewMouseUp:(NSEvent *)event inView:(NSView*)view;
- (void) imageDisplayViewMouseDragged:(NSEvent*)event inView:(NSView*)view;
- (void) imageDisplayViewtabletProximity:(NSEvent*)event inView:(NSView*)view;

@end


