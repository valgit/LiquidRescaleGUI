/*
 *
 */

#import <Cocoa/Cocoa.h>

@interface ImagePanelView : NSView
{
        IBOutlet id dataSource;
        IBOutlet id delegate;

	@private
	NSColor *_bgColor;

	NSPoint _anchor; // selection anchor 
	NSSize _size;   // selection size
	NSSize _thumbsize;
	double _scale;
}

- (id)initWithFrame:(NSRect)frame;

#pragma mark <Accessors>

- (NSPoint)anchor;
- (void)setAnchor:(NSPoint)point;
- (NSSize)selSize;
- (void)setSelSize:(NSSize)size;
- (void)setImageScale:(NSSize)size;

- (void)setBackgroundColor:(NSColor*)color;
- (NSColor*)backgroundColor;

#pragma mark <Delegate and Data Source Handling>
- (void) selectionDidChange;

- (void) setDataSource:(id)source;
- (void) setDelegate:(id)del;

@end

@interface  ImagePanelView (datasource)

- (NSSize) imagePanelViewImageSize:(NSView*)imageView;
- (NSImage*) imagePanelViewImageThumbnail:(NSView*)imageView withSize:(NSSize)size;

@end

@interface  ImagePanelView (delegate)

- (void) imagePanelViewSelectionDidChange:(NSView*)imageView;

@end

