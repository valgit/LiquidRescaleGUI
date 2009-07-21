
/* we need imageio */
#ifndef GNUSTEP
#import <ApplicationServices/ApplicationServices.h>
#import "NSImage+GTImageConversion.h"
#else
#import "NSImage-ProportionalScaling.h"
#endif
#import "MLog.h"
#import "LiquidRescaleController.h"
#import "NSFileManager-Extensions.h"

#include <math.h>

#define LS_CANCEL NSLocalizedStringFromTable(@"Cancel",  @"cancel", "Button choice for cancel")
#define LS_ERROR NSLocalizedStringFromTable(@"Error", @"error", @"title for error")
#define LS_CONTINUE NSLocalizedStringFromTable(@"Continue", @"continue", @"Button choice for continue")
#define LS_OK NSLocalizedStringFromTable(@"OK", @"ok", "Button choice for OK")

// Categories : private methods
@interface LiquidRescaleController (Private)
#ifndef GNUSTEP
- (NSImage*) createThumbnail:(CGImageSourceRef)imsource;
#endif
-(void)copyExifFrom:(NSString*)sourcePath to:(NSString*)outputfile with:(NSString*)tempfile;
-(NSString*)previewfilename:(NSString *)file;

-(void)setDefaults;
-(void)getDefaults;

-(NSString *)initTempDirectory;

- (void) checkBeta;

-(void)buildPreview;

@end

@implementation LiquidRescaleController

#pragma mark -
#pragma mark init & dealloc

// when first launched, this routine is called when all objects are created
// and initialized.  It's a chance for us to set things up before the user gets
// control of the UI.
-(void)awakeFromNib
{
    [self checkBeta];
	
	[window center];
	[window makeKeyAndOrderFront:nil];
	
	// this allows us to declare which type of pasteboard types we support
	//[mTableImage setDataSource:self];
	[mTableImage setRowHeight:128]; // have some place ...
	[mTableImage registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,NSStringPboardType,NSURLPboardType,nil]];
	// theIconColumn = [table tableColumnWithIdentifier:@"icon"];
	// [ic setImageScaling:NSScaleProportionally]; // or NSScaleToFit
	
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[self reset:mResetButton];
	[self getDefaults];

	//[self setTempPath:NSTemporaryDirectory()]; // TODO better
	[self setTempPath:[self initTempDirectory]];
	
	NSString* imageName = [[NSBundle mainBundle]
                    pathForResource:@"image_broken" ofType:@"png"];
	NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:imageName] autorelease];
	[mPreviewImage setImage:_image];
}

- (id)init
{
	if ( ! [super init])
        return nil;
	
	images = [[NSMutableArray alloc] init];
	useroptions = [[NSMutableDictionary alloc] initWithCapacity:5];
	
	return self;
}

- (void)dealloc
{
	
	[images release];
	
	if (useroptions != nil)
		[useroptions dealloc];
		
    [super dealloc];
}

-(void)openFile:(NSString *)file
{
	NSWorkspace *wm = [NSWorkspace sharedWorkspace];
	MLogString(1 ,@"tag: %d file : %@",[[mDoAfter selectedCell] tag],file);
	switch ([[mDoAfter selectedCell] tag]) {
		case 0 :
			[wm openFile:file withApplication:@"Photoshop" andDeactivate:YES];
			break;
		case 1 :
			[wm openFile:file];
			break;
		default : {
			// do nothing ? use for preview !
			NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:file] autorelease];
			[mPreviewImage setImage:_image];
			}
			break;
    }
}

// saving ?
-(id)propertyList {
   NSMutableDictionary *plist = [NSMutableDictionary dictionary];
   [plist setObject:@"1.0"  forKey:@"version"];

   [plist setObject:[NSNumber numberWithDouble:[mStepsSlider doubleValue]] forKey: @"steps"];
   [plist setObject:[NSNumber numberWithDouble:[mRigiditySlider doubleValue]] forKey: @"rigidity"];
   [plist setObject:[NSNumber numberWithDouble:[mPercentSlider doubleValue]] forKey: @"percent"];

   return plist;
}

- (NSData *) dataOfType: (NSString *) typeName
{

    NSMutableData *data = [[NSMutableData alloc] init];

    NSKeyedArchiver *archiver;
    archiver = [[NSKeyedArchiver alloc]
                   initForWritingWithMutableData: data];
    [archiver setOutputFormat: NSPropertyListXMLFormat_v1_0];

    [archiver encodeDouble: [mStepsSlider doubleValue]  forKey: @"steps"];
    [archiver encodeDouble: [mRigiditySlider doubleValue]  forKey: @"rigidity"];
    [archiver encodeDouble: [mPercentSlider doubleValue]  forKey: @"percent"];

    [archiver finishEncoding];

    return ([data autorelease]);

} 

- (BOOL) readFromData: (NSData *) data
              ofType: (NSString *) typeName
{
    NSKeyedUnarchiver *archiver;
    archiver = [[NSKeyedUnarchiver alloc]
                   initForReadingWithData: data];

    //stitches = [archiver decodeObjectForKey: @"stitches"];

    return (YES);

} 

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo {
	MLogString(1 ,@"error: %@", errorInfo);
	int result;
        result = NSRunAlertPanel([[NSProcessInfo processInfo] processName],
		NSLocalizedStringFromTable(@"file operation error", @"file error", @"file"),
		LS_CONTINUE,
	        LS_CANCEL, NULL,
                [errorInfo objectForKey:@"Error"],
                [errorInfo objectForKey:@"Path"]);

        if (result == NSAlertDefaultReturn)
                return YES;
        else
                return NO;
}


- (void) applicationWillTerminate: (NSNotification *)note 
{ 
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	MLogString(1 ,@"");
	//NSData* data = [self dataOfType:@"xml"];
	//[data writeToFile:@"/tmp/test.xml" atomically:YES ];
		NSDictionary* obj=nil;
	NSEnumerator *enumerator = [images objectEnumerator];
	
	while ( nil != (obj = [enumerator nextObject]) ) {
		//NSLog(@"removing : %@",[obj valueForKey:@"thumbfile"]);		
		[defaultManager removeFileAtPath:[obj valueForKey:@"thumbfile"] handler:self];
	}	

	// remove tempdir ...
	[defaultManager removeFileAtPath:[self temppath] handler:self];
	// [self saveSettings];
	[self setDefaults];
} 


#pragma mark -
#pragma mark table binding 

//speak well !	
-(NSString *)pluralImagesToProcess;
{
	return ([images count] <= 1)? @"" : @"s";
}

// KVC compliant for array
- (unsigned)countOfImages
{
	//NSLog(@"%s icount: %d",__PRETTY_FUNCTION__,[images count]);
	
	return [images count];
}

// minimum ...
// KVC compliant for array
-(NSDictionary *)objectInImagesAtIndex:(unsigned)index
{
#if 0
	NSImage* image;
	NSString *text;
	NSNumber *enable = [NSNumber numberWithBool: YES];
	
	MLogString(1 ,@"for: %d",index);
	// TODO : better check for null ...
	image = nil;
	if ( nil == image) {
		NSLog(@"%s : can't get thumbnail",__PRETTY_FUNCTION__);
	}
	// TODO : grab real value !
	text = [[@"test"  retain ] autorelease];
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",text,@"text",image,@"thumb",nil];  
#else
	return [images objectAtIndex:index];
#endif
}

// 
-(void)insertObject:(id)obj inImagesAtIndex:(unsigned)index;
{
	MLogString(1 ,@"obj is : %@",obj);
	[images insertObject: obj  atIndex: index];
}

-(void)removeObjectFromImagesAtIndex:(unsigned)index;
{
	MLogString(1 ,@"");
	[images removeObjectAtIndex: index];
}

-(void)replaceObjectInImagesAtIndex:(unsigned)index withObject:(id)obj;
{
	MLogString(1 ,@"");
	[images replaceObjectAtIndex: index withObject: obj];
}

/*
 * note to react at selection change :
 * [searchArrayController addObserver: self
                           forKeyPath: @"selectionIndexes"
							  options: NSKeyValueObservingOptionNew
							  context: NULL];
 
 * and use observeValueForKeyPath:						   
 */

#pragma mark -
#pragma mark drag drop from finder ?

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
{
	MLogString(1 ,@"");
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	MLogString(1 ,@"");
	// [tv setDropRow: -1 dropOperation:NSTableViewDropOn];
    //return NSDragOperationMove;
	
	if( [info draggingSource] == mTableImage )
	{
		/*if( operation == NSTableViewDropOn )
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
		*/
		/* if ((row==0)&&(operation==NSTableViewDropOn)) {
		[tv setDropRow:0 dropOperation:NSTableViewDropAbove];
		}*/
		return NSDragOperationEvery;
	} else 	{
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	MLogString(1 ,@"");
	NSPasteboard *pasteboard = [info draggingPasteboard];
	if ( [[pasteboard types] containsObject:NSFilenamesPboardType] ) {
		//NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
		NSArray * fileArray = [pasteboard propertyListForType: NSFilenamesPboardType];
		unsigned fileArrayCount = [fileArray count];
		if ( fileArray == nil || fileArrayCount < 1 ) return NO;
		
		//NSArray *allItemsArray = [itemsArrayController arrangedObjects];
		//NSMutableArray *draggedItemsArray = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
		
		// create and configure a new Image
		NSString *sourcePath = [fileArray objectAtIndex:0];
		NSImage* image =[[NSImage alloc] initWithContentsOfFile:sourcePath];
		NSNumber *enable = [NSNumber numberWithBool: YES];
		
		NSMutableDictionary *newImage = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",sourcePath,@"text",image,@"thumb",nil]; 
		[images insertObject:newImage atIndex:row];
		[newImage release];
		
	}
	
	return YES;
}

#pragma mark -
#pragma mark User Action

- (IBAction)cancel:(id)sender
{
	MLogString(1 ,@"");
	[ NSApp stopModal ];
	findRunning = NO;

}

- (IBAction)LiquidRescale:(id)sender
{
	MLogString(1 ,@"");	
}


- (IBAction)reset:(id)sender
{
	MLogString(1 ,@"");
	
	[mStepsSlider setIntValue:1]; // (0 <= steps <= 1).  Default: 1
	[self takeSteps:mStepsSlider];
	
	[mRigiditySlider setFloatValue:0.0]; // 0 <= rigidity <= 10).  Default: 0.0
	[self takeRigidity:mRigiditySlider];
	
	[mHeightSlider setFloatValue:0.2]; // 
	[self takeHeight:mHeightSlider];
	
	[mWidthSlider setFloatValue:0.5]; // 
	[self takeWidth:mWidthSlider];
	
	[mPercentSlider setFloatValue:100.0]; // (0 <= percent <= 100 ).  Default: 100.0
	[self takePercent:mPercentSlider];
}

- (IBAction) about: (IBOutlet)sender;
{
	MLogString(1 ,@"");
#if 0
// Method to load the .nib file for the info panel.
    if (!infoPanel) {
        if (![NSBundle loadNibNamed:@"InfoPanel" owner:self])  {
            NSLog(@"Failed to load InfoPanel.nib");
            NSBeep();
            return;
        }
        [infoPanel center];
    }
    [infoPanel makeKeyAndOrderFront:nil];
#endif
}

- (IBAction) chooseOutputDirectory: (id)sender;
{
	// Create the File Open Panel class.
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	
	[oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
	[oPanel setCanCreateDirectories:YES];
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel setAlphaValue:0.95];
	[oPanel setTitle:@"Select a directory for output"];

	NSString *outputDirectory;
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        if ([standardUserDefaults stringForKey:@"outputDirectory"]) {
                outputDirectory = [standardUserDefaults stringForKey:@"outputDirectory"];
        } else {
                outputDirectory = NSHomeDirectory();
                outputDirectory = [outputDirectory stringByAppendingPathComponent:@"Pictures"];
        }

	// Display the dialog.  If the OK button was pressed,
	// process the files.
	//      if ( [oPanel runModalForDirectory:nil file:nil types:fileTypes]
	if ( [oPanel runModalForDirectory:outputDirectory file:nil types:nil]
		 == NSOKButton )
	{
		// Get an array containing the full filenames of all
		// files and directories selected.
		NSArray* files = [oPanel filenames];
		
		NSString* fileName = [files objectAtIndex:0];
		MLogString(1 ,@"%@",fileName);
		[mOuputFile setStringValue:fileName];
		
	}
	
}


- (IBAction) quit: (id)sender;
{
	MLogString(1 ,@"");
}


#if 1
//  test for detecting end of sliding ...
//
- (IBAction)takeHeight:(id)sender {
	//MLogString(6 ,@"");
	
    SEL trackingEndedSelector = @selector(HeightsliderEnded:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:trackingEndedSelector object:sender];
    [self performSelector:trackingEndedSelector withObject:sender afterDelay:0.0];
	
    // do whatever you want to do during tracking here 
	float theValue = [sender floatValue];
	[mHeightTextField setFloatValue:theValue];
	[mHeightSlider setFloatValue:theValue];
	
}

- (void)HeightsliderEnded:(id)sender 
{
	MLogString(6 ,@"");
    // do whatever you want to do when tracking ends here 
    // call preview ?
	[self buildPreview];
}

- (IBAction)takeSteps:(id)sender {
	//MLogString(6 ,@"");
	
    SEL trackingEndedSelector = @selector(StepssliderEnded:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self
	 selector:trackingEndedSelector object:sender];
    [self performSelector:trackingEndedSelector withObject:sender afterDelay:0.0];
	
    // do whatever you want to do during tracking here 
	float theValue = [sender floatValue];
	[mStepsTextField setFloatValue:theValue];
	[mStepsSlider setFloatValue:theValue];	
}

- (void)StepssliderEnded:(id)sender 
{
	MLogString(6 ,@"");
    // do whatever you want to do when tracking ends here 
    // call preview ?
	[self buildPreview];
}

- (IBAction)takeRigidity:(id)sender {
	//MLogString(6 ,@"");

    SEL trackingEndedSelector = @selector(RigiditysliderEnded:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self
	selector:trackingEndedSelector object:sender];
    [self performSelector:trackingEndedSelector withObject:sender afterDelay:0.0];

    // do whatever you want to do during tracking here 
	float theValue = [sender floatValue];
	[mRigidityTextField setFloatValue:theValue];
	[mRigiditySlider setFloatValue:theValue];
}

- (void)RigiditysliderEnded:(id)sender 
{
	MLogString(6 ,@"");
    // do whatever you want to do when tracking ends here 
    // call preview ?
	[self buildPreview];
}

#else
// normal way ...
//
- (IBAction) takeHeight: (id)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mHeightTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mHeightSlider setFloatValue:theValue];
}

- (IBAction) takeSteps: (id)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mStepsTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mStepsSlider setFloatValue:theValue];
}

- (IBAction) takeRigidity: (id)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mRigidityTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mRigiditySlider setFloatValue:theValue];
}
#endif

- (IBAction) takePercent: (id)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mPercentTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mPercentSlider setFloatValue:theValue];
}

- (IBAction) takeWidth: (id)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mWidthTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mWidthSlider setFloatValue:theValue];
}

- (void) openPresetsDidEnd:(NSOpenPanel *)panel
             returnCode:(int)returnCode
            contextInfo:(void  *)contextInfo
{
	MLogString(1 ,@"");

  //Did they choose open?
  if(returnCode == NSOKButton) {
	//NSData* data = [NSData dataWithContentsOfFile:[panel filename]];
	//[self readFromData:data ofType:@"xml"];
	//[data release];
	NSData* plistData = [NSData dataWithContentsOfFile:[panel filename]];
	NSPropertyListFormat format;
	NSString *error;
	id plistDict = [NSPropertyListSerialization propertyListFromData:plistData
                                mutabilityOption:NSPropertyListImmutable
                                format:&format
                                errorDescription:&error];

	if(!plistDict) {
	    MLogString(1 ,@"%@",error);
	    [error release];
	} else {
		// TODO : better init ...
		//NSMutableDictionary* plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:[panel filename]];
		[mStepsSlider setFloatValue:[[plistDict objectForKey:@"steps"] floatValue]];
		[mRigiditySlider setFloatValue:[[plistDict objectForKey:@"rigidity"] floatValue]];
		[mHeightSlider setFloatValue:[[plistDict objectForKey:@"height"] floatValue]];
		[mWidthSlider setFloatValue:[[plistDict objectForKey:@"width"] floatValue]];
		[mPercentSlider setFloatValue:[[plistDict objectForKey:@"percent"] floatValue]];
	}
	//[plistDict release];
	//[plistData release];
  }
}

- (IBAction) openPresets: (IBOutlet)sender;
{
	MLogString(1 ,@"");
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	  [panel setCanChooseDirectories:NO];
	  [panel setCanChooseFiles:YES];
	  [panel setCanCreateDirectories:NO];
	  [panel setAllowsMultipleSelection:NO];
	  [panel setAlphaValue:0.95];
	  [panel setTitle:@"Select a preset"];

	  [panel beginSheetForDirectory: nil
		 file:nil
		 types:nil
		 modalForWindow: window // [self window ]
		 modalDelegate:self
		 didEndSelector:
		   @selector(openPresetsDidEnd:returnCode:contextInfo:)
		 contextInfo:nil];
}

- (void) savePresetsDidEnd:(NSSavePanel *)panel
             returnCode:(int)returnCode
            contextInfo:(void  *)contextInfo
{
	MLogString(1 ,@"");

  //Did they choose open?
  if(returnCode == NSOKButton) {

    //NSData* data = [self dataOfType:@"xml"];
    //[data writeToFile:[panel filename] atomically:YES ];
    // [plistDict writeToFile:[panel filename] atomically:YES ];
    NSMutableDictionary* plistDict = [self propertyList];
    NSString *error;
    NSData* xmlData = [NSPropertyListSerialization dataFromPropertyList:plistDict
                                       format:NSPropertyListXMLFormat_v1_0
                                       errorDescription:&error];

	if(xmlData) {
	    [xmlData writeToFile:[panel filename] atomically:YES];
	} else {
	    MLogString(1 ,@"%@",error);
	    [error release];
	}
  }
}

- (IBAction) savePresets: (IBOutlet)sender;
{
	MLogString(1 ,@"");
	NSSavePanel *panel = [NSSavePanel savePanel];

	  //[panel setCanCreateDirectories:YES];
	  //[panel setAllowsMultipleSelection:NO];
	  [panel setAlphaValue:0.95];
	  [panel setTitle:@"Save preset"];

	  [panel beginSheetForDirectory: nil
		 file:@"default.plist" // default filename
		 modalForWindow: window // [self window ]
		 modalDelegate:self
		 didEndSelector:
		   @selector(savePresetsDidEnd:returnCode:contextInfo:)
		 contextInfo:nil];
}

// If the user closes the search window, let's just quit
-(BOOL)windowShouldClose:(id)sender
{
    if (findRunning == YES) {
		//[LiquidRescaleTask stopProcess];
		// Release the memory for this wrapper object
		//[LiquidRescaleTask release];
		//LiquidRescaleTask=nil;
    }
	
    [NSApp terminate:nil];
    return YES;
}

#pragma mark -
#pragma mark tableview delegate

//
// tableview delegate and datasources ...
//

// return the number of row int the table
- (int)numberOfRowsInTableView: (NSTableView *)aTable
{
	MLogString(1 ,@"");
	//return [images count];
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	MLogString(1 ,@"");
	// TODO return [[images objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
	return nil;
}

// use a delegate do watch the selection ...
- (void)tableViewSelectionDidChange:
	(NSNotification *)aNotification
{
	int row = [mTableImage selectedRow];
	if (row >= 0)
	{
		// display info in the drawer ...
		NSLog(@"the user just clicked on row %d -> %@", row,
			  /* [[images objectAtIndex:row] objectForKey:@"name"] */ @"TODO" );
	}
}


// button action ...
- (IBAction)addImage:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// Create the File Open Panel class.
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	
	[oPanel setCanChooseDirectories:NO];
	[oPanel setCanChooseFiles:YES];
	[oPanel setCanCreateDirectories:YES];
	[oPanel setAllowsMultipleSelection:YES];
	[oPanel setAlphaValue:0.95];
	[oPanel setTitle:@"Select a image to add"];
	
	// Display the dialog.  If the OK button was pressed,
	// process the files.
	//      if ( [oPanel runModalForDirectory:nil file:nil types:fileTypes]
	if ( [oPanel runModalForDirectory:nil file:nil types:nil]
		 == NSOKButton )
	{
		// Get an array containing the full filenames of all
		// files and directories selected.
		NSArray* files = [oPanel filenames];
		
		unsigned fileArrayCount = [files count];
		int i;
		
		for(i=0;i<fileArrayCount;i++) {
		NSString* fileName = [files objectAtIndex:i];
		MLogString(1 ,@"%@",fileName);
		
		NSImage* image;
		NSString *text;
#ifdef GNUSTEP
		// create and configure a new Image
		image =[[NSImage alloc] initWithContentsOfFile:fileName];
		// create a meaning full info ...

		NSBitmapImageRep *rep =[image bestRepresentationForDevice:nil];
		NSMutableDictionary *exifDict =  [rep valueForProperty:@"NSImageEXIFData"];
#else
		
		CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:fileName], NULL);
		if(source != nil) {
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
				(id)kCFBooleanTrue, (id)kCGImageSourceShouldCache,
				(id)kCFBooleanTrue, (id)kCGImageSourceShouldAllowFloat,
				NULL];
			
			// get Exif from source?
			NSDictionary* properties =  (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, (CFDictionaryRef)options);
			//NSLog(@"props: %@", [properties description]);
			NSDictionary *exif = [properties objectForKey:(NSString *)kCGImagePropertyExifDictionary];
			if(exif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
				NSString *focalLengthStr, *fNumberStr, *exposureTimeStr,*exposureBiasStr;
				//MLogString(1 ,@"the exif data is: %@", [exif description]);
				NSNumber *focalLengthObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFocalLength];
				if (focalLengthObj) {
					focalLengthStr = [NSString stringWithFormat:@"%@mm", [focalLengthObj stringValue]];
				}
				NSNumber *fNumberObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFNumber];
				if (fNumberObj) {
					fNumberStr = [NSString stringWithFormat:@"F%@", [fNumberObj stringValue]];
				}
				NSNumber *exposureTimeObj = (NSNumber *)[exif objectForKey:(NSString *)kCGImagePropertyExifExposureTime];
				if (exposureTimeObj) {
					exposureTimeStr = [NSString stringWithFormat:@"1/%.0f", (1/[exposureTimeObj floatValue])];
				}
				NSNumber *exposureBiasObj = (NSNumber *)[exif objectForKey:@"ExposureBiasValue"];
				if (exposureBiasObj) {
					exposureBiasStr = [NSString stringWithFormat:@"Exposure Comp. : %+0.1f EV", [exposureBiasObj floatValue]];
				} else 
					exposureBiasStr = @"";
				
				text = [NSString stringWithFormat:@"%@\n%@ / %@ @ %@\n%@", [fileName lastPathComponent],
					focalLengthStr,exposureTimeStr,fNumberStr,exposureBiasStr];
			} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifRigidityTime kCGImagePropertyExifRigidityTime */
			image = [self createThumbnail:source];
			CFRelease(source);
			CFRelease(properties);
		} else {
			text = [fileName lastPathComponent];
		}        
#endif
#ifdef GNUSTEP		
		//NSLog(@"Exif Data in  %@", exifDict);
		// TODO better with ImageIO
		if (exifDict != nil) {
			NSNumber *expo = [exifDict valueForKey:@"RigidityTime"];
			NSString *speed;
			if (expo)
				speed = [NSString stringWithFormat:@"1/%.0f",ceil(1.0 / [expo doubleValue])];
			else
				speed = @"";
			
			text = [NSString stringWithFormat:@"%@\n%@ @ f/%@", [fileName lastPathComponent],
				speed,[exifDict valueForKey:@"FNumber"]];
		} else {
			text = [fileName lastPathComponent];
		}
#endif
		
		NSData *thumbData = [image  TIFFRepresentation];
		NSString *thumbname = [self previewfilename:[fileName lastPathComponent]];
		[thumbData writeToFile:thumbname atomically:YES];
		
		NSNumber *enable = [NSNumber numberWithBool: YES];
		// [NSString stringWithFormat: 
		NSMutableDictionary *newImage = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",fileName,@"file",text,@"text",image,@"thumb",thumbname,@"thumbfile",nil]; 
#ifdef GNUSTEP
		[images addObject:newImage];
		[mTableImage reloadData];
        	//[mTableImage scrollRowToVisible:[mTableImage numberOfRows]-1];
		

#else
		[mImageArrayCtrl addObject:newImage];
#endif
		[self buildPreview];
		//[newImage release]; // memory bug ?
		}
		
		
	}
	
	
}


#pragma mark -
#pragma mark TODO

-(NSString*)outputfile;
{
	return _outputfile;
}

-(void)setOutputfile:(NSString *)file;
{
	if (_outputfile != file) {
		[_outputfile release];
        _outputfile = [file copy];
	}
}

-(NSString*)tempfile;
{
	return _tmpfile;
}

-(void)setTempfile:(NSString *)file;
{
	if (_tmpfile != file) {
		[_tmpfile release];
        _tmpfile = [file copy];
	}
}

-(NSString*)temppath;
{
        return _tmppath;
}

-(void)setTempPath:(NSString *)file;
{
        if (_tmppath != file) {
                [_tmppath release];
        _tmppath = [file copy];
        }
}



- (IBAction)revealInFinder:(IBOutlet)sender {
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self outputfile] isDirectory:&isDir]) {
		if (isDir)
			[[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:[self outputfile]];
		else
			[[NSWorkspace sharedWorkspace] selectFile:[self outputfile] inFileViewerRootedAtPath:nil];
    }
}

- (IBAction)preferencesSaving:(id)sender;
{
	MLogString(1 ,@"");
}

- (IBAction)openPreferences:(id)sender
{
	MLogString(1 ,@"");
}

@end

@implementation LiquidRescaleController (Private)

// return a somewhat globally unique filename ...
// 
-(NSString*)previewfilename:(NSString *)file
{
      NSString *tempFilename = [self temppath]; // NSTemporaryDirectory();
    
      return [[NSString stringWithFormat:@"%@/thumb_%@",tempFilename,file] retain];
}

#ifndef GNUSTEP
// create a thumbnail using imageio framework
- (NSImage*) createThumbnail:(CGImageSourceRef)imsource
{
	CGImageRef _thumbnail = nil;
	
	if (imsource) {		
		// Ask ImageIO to create a thumbnail from the file's image data, if it can't find a suitable existing thumbnail image in the file.  
		// We could comment out the following line if only existing thumbnails were desired for some reason
		//  (maybe to favor performance over being guaranteed a complete set of thumbnails).
		NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
			(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
			(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent, // kCGImageSourceCreateThumbnailFromImageAlways
			[NSNumber numberWithInt:160], (id)kCGImageSourceThumbnailMaxPixelSize, 
			nil];
		
		// make image thumbnail
		_thumbnail = CGImageSourceCreateThumbnailAtIndex(imsource, 0, (CFDictionaryRef)thumbOpts);
		//NSImage *image = [[NSImage alloc] initWithCGImage:_thumbnail];
		NSImage *image = [NSImage gt_imageWithCGImage:_thumbnail];	
		
	
	
		CFRelease(_thumbnail);
		return image;
	}
	return NULL;
}
#endif

-(void)copyExifFrom:(NSString*)sourcePath to:(NSString*)outputfile with:(NSString*)tempfile;
{
	NSMutableDictionary* newExif;
	MLogString(1 ,@"");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#ifndef GNUSTEP
	
	// create the source 
	NSURL *_url = [NSURL fileURLWithPath:sourcePath]; // for exif
	NSURL *_outurl = [NSURL fileURLWithPath:outputfile]; // dest
	NSURL *_tmpurl = [NSURL fileURLWithPath:tempfile]; // for image
	CGImageSourceRef exifsrc = CGImageSourceCreateWithURL((CFURLRef)_url, NULL);
	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)_tmpurl, NULL);
	if(source != nil) {
		// get Exif from source?
		NSDictionary* metadata = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(exifsrc, 0, NULL);
		//make the metadata dictionary mutable so we can add properties to it
		NSMutableDictionary *metadataAsMutable = [[metadata mutableCopy]autorelease];
		[metadata release];
	
		//NSLog(@"props: %@", [(NSDictionary *)properties description]);
		 NSMutableDictionary *newExif = [[[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary]mutableCopy]autorelease];
    
		if(!newExif) {
			//if the image does not have an EXIF dictionary (not all images do), then create one for us to use
			newExif = [NSMutableDictionary dictionary];
		}
	
		//NSDictionary *exif = (NSDictionary *)[properties objectForKey:(NSString *)kCGImagePropertyExifDictionary];
		if(newExif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
			//NSLog(@"the exif data is: %@", [exif description]);
			//newExif = [NSMutableDictionary dictionaryWithDictionary:exif];

			if ([mCopyShutter state]==NSOnState) {
				MLogString(1 ,@"removing shutter speed");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifExposureTime];
			}
			if ([mCopyAperture state]==NSOnState) {
				MLogString(1 ,@"removing aperture");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFNumber];
			}
			if ([mCopyFocal state]==NSOnState) {
				MLogString(1 ,@"removing focal length");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFocalLength];
			}
		} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifRigidityTime kCGImagePropertyExifRigidityTime */
		
		//add our modified EXIF data back into the image’s metadata
		[metadataAsMutable setObject:newExif forKey:(NSString *)kCGImagePropertyExifDictionary];
		
		// create the destination
		CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)_outurl,
				CGImageSourceGetType(source),
				CGImageSourceGetCount(source),
				NULL);
	
		//CGImageDestinationSetProperties(destination, (CFDictionaryRef)exif);	

		// copy data from temporary image ...
		int imageCount = CGImageSourceGetCount(source);
		int i;
		for (i = 0; i < imageCount; i++) {
				//NSLog(@"imgs  : %d",i);
				CGImageDestinationAddImageFromSource(destination,
						     source,
						     i,
						     (CFDictionaryRef)metadataAsMutable);
		}
    
		CGImageDestinationFinalize(destination);
    
		CFRelease(destination);
		CFRelease(source); 
		//CFRelease(properties);
		//CFRelease(exifsrc); 
	} else {
		NSRunInformationalAlertPanel(@"Copying Exif error!",
									 @"Unable to add Exif to Image.",
									 @"OK",
									 nil,
									 nil,
									 nil);
	}
	NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:(tempfile)]){
		[fm removeFileAtPath:tempfile handler:self];
	}
#else
	NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:(tempfile)]){
              BOOL result = [fm movePath:tempfile toPath:outputfile handler:nil];
        } else {
              NSString *alert = [tempfile stringByAppendingString: @" do not exist!\nCan't rename"];
              NSRunAlertPanel (NSLocalizedString(@"Fatal Error",@""), alert, @"OK", NULL, NULL);
        }
#endif
	[pool release];
}

// write back the defaults ...
-(void)setDefaults;
{
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if (standardUserDefaults) {
			
              [standardUserDefaults setObject:[mOuputFile stringValue] forKey:@"outputDirectory"];
              [standardUserDefaults setObject:[mOutFile stringValue] forKey:@"outputFile"];
              [standardUserDefaults setObject:[mAppendTo stringValue] forKey:@"outputAppendTo"];
              [standardUserDefaults setObject:[mOutQuality stringValue] forKey:@"outputQuality"];
	
	  id obj = [useroptions valueForKey:@"importInAperture"];
	  if (obj != nil)
	  [standardUserDefaults setObject:obj
					forKey:@"importInAperture"];

	  obj = [useroptions valueForKey:@"stackWithOriginal"];
	  if (obj != nil)
	  [standardUserDefaults setObject:obj
					 forKey:@"stackWithOriginal"];

	  obj = [useroptions valueForKey:@"addKeyword"];
	  if (obj != nil) {
		  [standardUserDefaults setObject:obj
					 forKey:@"addKeyword"];
		  if ([obj boolValue])
			[standardUserDefaults setObject:[useroptions valueForKey:@"keyword"]
					 forKey:@"keyword"];
			 
	   } 
              [standardUserDefaults synchronize];
        }
}

// read back the defaults ...
-(void)getDefaults;
{
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if (standardUserDefaults) {
			  NSString *temp;
			  
			  temp = [standardUserDefaults objectForKey:@"outputDirectory"];
			  if (temp != nil)
				[mOuputFile setStringValue:temp];
			  
			  temp = [standardUserDefaults objectForKey:@"outputFile"];
			  if (temp != nil)
				[mOutFile setStringValue:temp];
			  
			  temp = [standardUserDefaults objectForKey:@"outputAppendTo"];
			  if (temp != nil)
				[mAppendTo setStringValue:temp];
				
			  temp = [standardUserDefaults objectForKey:@"outputQuality"];
			  if (temp != nil)
				[mOutQuality setStringValue:temp];
				
			[useroptions setValue:[standardUserDefaults objectForKey:@"importInAperture"]
				forKey:@"importInAperture"];
			[useroptions setValue:[standardUserDefaults objectForKey:@"stackWithOriginal"]
				forKey:@"stackWithOriginal"];
			[useroptions setValue:[standardUserDefaults objectForKey:@"addKeyword"]
				forKey:@"addKeyword"];
			if ([[useroptions valueForKey:@"addKeyword"] boolValue])
				[useroptions setValue:[standardUserDefaults objectForKey:@"keyword"]
					forKey:@"keyword"];
        }
}

-(NSString *)initTempDirectory;
{
        // Create our temporary directory
                NSString* tempDirectoryPath = [NSString stringWithFormat:@"%@/LiquidRescaleGUI", 
				NSTemporaryDirectory()];

                // If it doesn't exist, create it
                NSFileManager *fileManager = [NSFileManager defaultManager];
                BOOL isDirectory;
                if (![fileManager fileExistsAtPath:tempDirectoryPath isDirectory:&isDirectory])
                {
                        [fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
                }
                else if (isDirectory) // If a folder already exists, empty it.
                {
                        NSArray *contents = [fileManager directoryContentsAtPath:tempDirectoryPath];
                        int i;
                        for (i = 0; i < [contents count]; i++)
                        {
                                NSString *tempFilePath = [NSString stringWithFormat:@"%@/%@", 
					tempDirectoryPath, [contents objectAtIndex:i]];
                                [fileManager removeFileAtPath:tempFilePath handler:nil];
                        }
                }
                else // Delete the old file and create a new directory
                {
                        [fileManager removeFileAtPath:tempDirectoryPath handler:nil];
                        [fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
                }
		return tempDirectoryPath;
}

//
// check if this beta version has expired !
- (void) checkBeta;
{
	NSDate *expirationDate = 
	[[NSDate dateWithNaturalLanguageString:
		[NSString stringWithCString:__DATE__]] 
            addTimeInterval:(60*60*24*30/*30 days*/)];
	
    if( [expirationDate earlierDate:[NSDate date]] 
		== expirationDate )
    {
        int result = NSRunAlertPanel(@"Beta Expired", 
									 @"This beta has expired, please visit "
									 "http://vald70.free.fr/ to grab"
									 "the latest version.", 
									 @"Take Me There", @"Exit", nil);
		
        if( result == NSAlertDefaultReturn )
        {
            [[NSWorkspace sharedWorkspace] openURL:
				[NSURL URLWithString:
							  @"http://vald70.free.fr/"]];
        }
        [[NSApplication sharedApplication] terminate:self];
    }
}

-(void)buildPreview;
{
	MLogString(6 ,@"");
	
	if ([self countOfImages] == 0) {
		MLogString(5 ,@"preview : no images");
		return ;
	}
	
	NSMutableArray *args = [NSMutableArray array];

	MLogString(4 ,@"preview file is %@",[self previewfilename:@"LiquidRescale.tif"]);

	// gather thumbnail ...
	NSDictionary* obj=nil;
        NSEnumerator *enumerator = [images objectEnumerator];

        while ( nil != (obj = [enumerator nextObject]) ) {
	   if ([[obj valueForKey:@"enable"] boolValue]){
		   [args addObject:[obj valueForKey:@"thumbfile"]];
	   }
        }
}

@end
