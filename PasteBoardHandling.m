//
//  PasteboardHandling.m
//
//

#import "PasteBoardHandling.h"

@implementation LiquidRescaleController (PasteboardHandling)
    
- (IBAction) copy:(id)sender
{
    NSPasteboard 
        *pboard = [NSPasteboard generalPasteboard];
    NSArray 
        *types = [NSArray arrayWithObject:NSTIFFPboardType];
        
    //NSLog(@"copy");
    [pboard declareTypes:types owner:self];
    [pboard addTypes:types owner:self];
}
    
- (IBAction) paste:(id)sender
{
    NSLog(@"paste");
#if 0
    NSImage 
        *newImage = [[NSImage alloc] initWithData:[[NSPasteboard generalPasteboard] dataForType:NSTIFFPboardType]];
    if (newImage) {
        [originalImageView setImage:newImage];
        [self imageChanged:nil];
    }
#endif
}
    
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
{
    //NSLog(@"pasteboard");
    [sender setData:[_image TIFFRepresentation] forType:NSTIFFPboardType];
}

@end

