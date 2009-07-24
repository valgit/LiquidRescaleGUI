/*
 *
 */

#import <Cocoa/Cocoa.h>

@interface ImageDisplayView : NSView
{
	NSImage* _beforeImage;
	NSImage* _afterImage;

	NSColor *_bgColor;

	BOOL _displayAfter;
}

- (id)initWithFrame:(NSRect)frame;

-(void)setBeforeImage:(NSImage*)image;
- (NSImage*)beforeImage;
-(void)setAfterImage:(NSImage*)image;
- (NSImage*)afterImage;
- (void)reloadImage;

- (void)setDisplayAfter:(BOOL)state;

- (void)setBackgroundColor:(NSColor*)color;
- (NSColor*)backgroundColor;

@end


