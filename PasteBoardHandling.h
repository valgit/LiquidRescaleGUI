#import "LiquidRescaleController.h"

@interface LiquidRescaleController (PasteboardHandling)

- (void) copy:(id)sender;
- (void) paste:(id)sender;

@end

@interface NSPasteboard (hasType)

- (BOOL) hasType:aType;

@end


