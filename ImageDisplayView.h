/*
 *
 */

#import <Cocoa/Cocoa.h>

@interface ImageDisplayView : NSView
{
	NSImage* _image;
	NSColor *_bgColor;
}

- (id)initWithFrame:(NSRect)frame;

-(void)setImage:(NSImage*)image;
- (void)setBackgroundColor:(NSColor*)color;
- (NSImage*)image;
- (NSColor*)backgroundColor;

@end


