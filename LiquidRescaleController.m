
/* we need imageio */
#ifndef GNUSTEP
#import <ApplicationServices/ApplicationServices.h>
#import "NSImage+GTImageConversion.h"
#else
#import "NSImage-ProportionalScaling.h"
#endif

#import "NSImage+Cropped.h"
#import "MLog.h"
#import "LiquidRescaleController.h"
#import "NSFileManager-Extensions.h"
#import "CTProgressBadge.h"

#import "ImagePanelView.h"
#import "ImageDisplayView.h"

#include <math.h>
#include "lqr.h"

// TODO: have the lib 
//#define GET_TEXT 1
#ifndef GET_TEXT
void libintl_gettext()
{
}

void libintl_bind_textdomain_codeset()
{
}

void libintl_bindtextdomain()
{
}
void libintl_textdomain()
{
}

void libintl_dngettext()
{
}

void libintl_dgettext()
{
}
#endif

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

- (void) progress_init:(NSString*)message;
- (void) progress_update:(NSNumber*)percent;
- (void) progress_end:(NSString*)message;

- (void) buildSkinToneBias;

@end

// TODO: place in their own files
// some global C functions
/* define custom energy function: sobel */
gfloat
sobel(gint x, gint y, gint w, gint h, LqrReadingWindow *rw, gpointer extra_data)
{
    gint i, j;
    gdouble ex = 0;
    gdouble ey = 0;
    gdouble k[3][3] = { {0.125, 0.25, 0.125}, {0, 0, 0}, {-0.125, -0.25, -0.125} };

    for (i = -1; i <= 1; i++) {
        for (j = -1; j <= 1; j++) {
            ex += k[i + 1][j + 1] * lqr_rwindow_read(rw, i, j, 0);
            ey += k[j + 1][i + 1] * lqr_rwindow_read(rw, i, j, 0);
        }
    }
    return (gfloat) (sqrt(ex * ex + ey * ey));
}

// determine if a color is skin tone or not !
// return bias value 
BOOL isSkinTone(int r,int g,int b)
{
    // NOTE: color is previously converted to eight bits.
    double R = r   / 255.0;
    double G = g / 255.0;
    double B = b  / 255.0;
    double S = R + G + B;

    return( (B/G         < 1.249) &&
            (S/3.0*R     > 0.696) &&
            (1.0/3.0-B/S > 0.014) &&
            (G/(3.0*S)   < 0.108)
          );
}

// TODO: better GUI here !
LqrRetVal my_progress_init(const gchar *message)
{

  //fprintf(stderr,"lqr: <start> %s\n",message);
  LiquidRescaleController* controller = [ NSApp delegate];
  NSString *msgString = [[NSString alloc] initWithCString:message
                              encoding:NSASCIIStringEncoding];
  [controller performSelectorOnMainThread:@selector(progress_init:) withObject:msgString waitUntilDone:NO];
  //[controller progress_init:msgString];
  [msgString release];
  return LQR_OK;
}

LqrRetVal my_progress_update(gdouble percentage)
{
  //fprintf(stderr,"lqr: %.2f %%\n",100*percentage);
  LiquidRescaleController* controller = [ NSApp delegate]; 
  NSNumber* percent = [NSNumber numberWithDouble:(percentage)];
  [controller performSelectorOnMainThread:@selector(progress_update:) withObject:percent waitUntilDone:NO];
  //NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
  //[controller progress_update:percent];
  return LQR_OK;
}

LqrRetVal my_progress_end(const gchar *message)
{
  //fprintf(stderr,"lqr: <end> %s\n",message);
  LiquidRescaleController* controller = [ NSApp delegate];
  NSString *msgString = [[NSString alloc] initWithCString:message
                              encoding:NSASCIIStringEncoding];
  [controller performSelectorOnMainThread:@selector(progress_end:) withObject:msgString waitUntilDone:NO];
  //[controller progress_end:msgString];
  [msgString release];
  return LQR_OK;
}

/*
 * energy functions :
 * LQR_EF_GRAD_XABS
 * LQR_EF_GRAD_SUMABS
 * LQR_EF_GRAD_NORM
 * LQR_ER_BRIGHTNESS (sobel)
 */

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

	// set the scroll to top !
	NSPoint pt = NSMakePoint(0.0, [[mParametersView documentView] bounds].size.height);
	[[mParametersView documentView] scrollPoint:pt];
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[self reset:mResetButton];
	[self getDefaults];

	//[self setTempPath:NSTemporaryDirectory()]; // TODO better
	[self setTempPath:[self initTempDirectory]];
	
	NSString* imageName = [[NSBundle mainBundle]
                    pathForResource:@"image_broken" ofType:@"png"];
	//NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:imageName] autorelease];
	//_image = [[[NSImage alloc] initWithContentsOfFile:imageName] autorelease];
	_image = NULL;
	//[mPreviewImage setImage:_image];
	[self setZoomFactor:100.0];
	[_imageView setDelegate:self]; // TODO: in nib
	myBadge = [[CTProgressBadge alloc] init];
	
	// init brushes
	_retainColor = [[NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:0.5] retain];
	_removalColor = [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.5] retain];
	_clearColor = [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0] retain];

	[mMaskToolButton setSelectedSegment:0];
}

- (id)init
{
	if ( ! [super init])
        return nil;
	
	images = [[NSMutableArray alloc] init];
	useroptions = [[NSMutableDictionary alloc] initWithCapacity:5];

	// Create a progress object
	progress = lqr_progress_new();
        lqr_progress_set_init(progress, my_progress_init);
        lqr_progress_set_update(progress, my_progress_update);
        lqr_progress_set_end(progress, my_progress_end);

	lqr_progress_set_init_width_message(progress, "Resizing width  :");
	lqr_progress_set_init_height_message(progress, "Resizing height :");
        lqr_progress_set_end_width_message(progress, "done");
        lqr_progress_set_end_height_message(progress, "done");
	lqr_progress_set_update_step(progress, 0.01);

	mLastPoint = NSZeroPoint;
	mLeftOverDistance = 0.0;	

	return self;
}

- (void)dealloc
{
	
	[images release];
	[_retainColor release];
	[_removalColor release];
	
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
			// TODO: 
			//NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:file] autorelease];
			//[mPreviewImage setImage:_image];
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
	//MLogString(1 ,@"obj is : %@",obj);
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
	cancelscaling = NO;
	lqr_carver_cancel(carver);
}

- (void) startRescaling;
{
  MLogString(1 ,@"");	
  //NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
#if 1
  [NSApp beginSheet: mProgressPanel
        modalForWindow: window modalDelegate: nil
        didEndSelector: nil contextInfo: nil ];
  //[NSApp runModalForWindow: mProgressPanel ];
#endif
}

- (void) endRescaling;
{
  MLogString(1 ,@"");	
  //NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
  [NSApp stopModal ];
  [NSApp endSheet: mProgressPanel ];
  [mProgressPanel orderOut: self ];
  //[panel close];
}

#pragma mark -
#pragma mark worker thread...

- (void) lqrRescaling:(NSDictionary*)infos;
{
	// Since we are being spun off into a thread, we need our own auto-release pool
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	MLogString(1 ,@"");	
	//NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
	
	NSNumber* Width = (NSNumber *)[infos objectForKey:@"width"];
	int width = [Width intValue];
	NSNumber* Height = (NSNumber *)[infos objectForKey:@"height"];
	int height = [Height intValue];
	
	// Signal that we are ready to start so that our progress sheet is displayed
	[self performSelectorOnMainThread:@selector(startRescaling) withObject:nil waitUntilDone:NO];
	
	/**** (II) LIQUID RESCALE ****/
	if (lqr_carver_resize(carver, width, height) == LQR_NOMEM) {
		// TODO : add warning
		NSLog(@"not enough memory !");
	}
	
	/**** (III) get the new data ****/
	int w = lqr_carver_get_width(carver);
	int h = lqr_carver_get_height(carver);
	MLogString(1 ,@"resizing data (%d,%d,%d) ",w,h,lqr_carver_get_channels(carver));
	// TODO: is it needed ?
	if (lqr_carver_get_channels(carver) != 3) {
		NSLog(@"bad channel number !");
		return;
	}
	
	
	// create a new representation without the alpha plane ...
	NSBitmapImageRep *destImageRep = [[[NSBitmapImageRep alloc]                                            
									   initWithBitmapDataPlanes:NULL                                                               
									   pixelsWide:w                                                          
									   pixelsHigh:h                                                          
									   bitsPerSample:8 // [rep bitsPerSample]                                
									   samplesPerPixel:3                                                     
									   hasAlpha:NO                                                             
									   isPlanar:NO                                                             
									   colorSpaceName:NSCalibratedRGBColorSpace                              
									   bytesPerRow:0 // (spp*width)                                           
									   bitsPerPixel:24 ] autorelease];          
	
	int destBpr = [destImageRep bytesPerRow];
	int destspp = [destImageRep samplesPerPixel];
	unsigned char* destpix = [destImageRep bitmapData];
	NSLog(@"%s exporting photo Bpr = %d,  Spp = %d (alpha: %d)",__PRETTY_FUNCTION__,
		  destBpr,destspp, [destImageRep hasAlpha] );
	
	unsigned char *rgb;
	int x,y;
	lqr_carver_scan_reset(carver);
	while (lqr_carver_scan(carver, &x, &y, &rgb)) {
		unsigned char *q = (unsigned char *)(destpix + destBpr*y);
		q[destspp*x] = rgb[0]; // red
		q[destspp*x+1] = rgb[1]; // green
		q[destspp*x+2] = rgb[2];
	}
	//NSData *photoData = [destImageRep representationUsingType:NSTIFFFileType properties:NULL];
	//   [photoData writeToFile:@"test.tif" atomically:YES];
	
#ifdef _TODO_
	// TODO: compilation !
	// make data provider from buffer
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, destpix, (width * height * destspp), NULL);
	
	if (provider != NULL) {
		CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
		CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault
		CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
		CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, 
											bytesPerRow, colorSpaceRef, bitmapInfo,
											provider, NULL, NO, renderingIntent);
	}
#endif
	
	NSImage *image = [[NSImage alloc] initWithSize:[destImageRep size]];
	[image addRepresentation:destImageRep];
	
	[_rescaleImage release];
	_rescaleImage = image;
	//[_panelImageView reloadImage];
	[_imageView setAfterImage:_rescaleImage];
	[_imageView setDisplayAfter:YES];
	
	//TODO: should be done on release ?
	/**** (IV) delete structures ? ****/
	
	// Finally, signal that we are done so that the UI becomes active again.
	[self performSelectorOnMainThread:@selector(endRescaling) withObject:nil waitUntilDone:NO];
	
	// Clean out our auto release pool.
	[pool release];
}

- (IBAction)LiquidRescale:(id)sender
{
	MLogString(1 ,@"");	
	if (_image != NULL) {
	  NSSize imSize = [_image size];
	  int w = imSize.width;
	  int h = imSize.height;

	 // TODO: from interface !
	  int max_step = [mStepsSlider intValue];
	  double rigidity =  [mRigiditySlider doubleValue];
	  int side_switch_frequency = 0;
	  double enl_step = 1.5;

	  MLogString(1 ,@"steps: %d, rig: %f ",max_step,rigidity);

	  int width = [mWidthSlider intValue];
	  int height = [mHeightSlider intValue];

	  _stage = NO;
	  _hResize = (h == height) ? NO : YES;
	  _wResize = (w == width) ? NO : YES;

	  MLogString(1 ,@"resizing to (%d,%d) ",width,height);
	  if ([mPercentSlider doubleValue] <100.0) { // mixed rescale 
		double stdRescaleP = (100.0 - [mPercentSlider doubleValue]) / 100.0;
		int diff_w         = (int)(stdRescaleP * (w - width));
		int diff_h         = (int)(stdRescaleP * (h - height));

		//imTemp.resize(imTemp.width() - diff_w, imTemp.height() - diff_h);
		MLogString(1 ,@"mix resize with (%d,%d) -> (%d,%d) ",diff_w,diff_h,
			w - diff_w, h - diff_h);
		// TODO: call cifilter here !
	  }

	  /* (I.2) initialize the carver (with default values),
	   *          so that we can do the resizing */
	  lqr_carver_init(carver, max_step, rigidity);
	  lqr_carver_set_progress(carver, progress);

	  /* (I.3a.3) set the energy function */
	  lqr_carver_set_energy_function(carver, sobel, 1, LQR_ER_BRIGHTNESS, NULL);

	  /* (I.3b.5) set the side switch frequency */
	  lqr_carver_set_side_switch_frequency(carver, side_switch_frequency);

	  /* (I.3b.6) set the enlargement step */
	  lqr_carver_set_enl_step(carver, enl_step);

	  // Choose the resize order
	  if ([mResizeOrderCombo indexOfSelectedItem] == 0)
            lqr_carver_set_resize_order(carver, LQR_RES_ORDER_HOR);
          else
            lqr_carver_set_resize_order(carver, LQR_RES_ORDER_VERT);


	  // TODO: bias and co here ...
	  if([mAddWeightMaskButton state]==NSOnState) {
		MLogString(1 ,@"creating mask");
	  }

	  if([mPreserveSkinTonesButton state]==NSOnState) {
		MLogString(1 ,@"try preserving skin tones");
		[self buildSkinToneBias];
	  }


	  /**** (II) LIQUID RESCALE ****/
	  // And dispatch the operation to a background thread to avoid locking up the UI.
          // detachNewThreadSelector:toTarget:withObject: will retain it's parameters so we don't have to.
	  NSDictionary *infos = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInt:width], @"width",
                [NSNumber numberWithInt:height], @"height",
                nil];

	  //[self lqrRescaling:infos];
	  [NSThread detachNewThreadSelector:@selector(lqrRescaling:) toTarget:self withObject:infos];

	} else
              NSRunCriticalAlertPanel ([[NSProcessInfo processInfo] processName],
			NSLocalizedString(@"No Image Loaded",@""), 
			LS_OK, NULL, NULL);
}


- (IBAction)reset:(id)sender
{
	MLogString(1 ,@"");
	
	[mStepsSlider setIntValue:1]; // (0 <= steps <= 1).  Default: 1
	[self takeSteps:mStepsSlider];
	
	[mRigiditySlider setFloatValue:0.0]; // 0 <= rigidity <= 10).  Default: 0.0
	[self takeRigidity:mRigiditySlider];
	
	[mPercentSlider setFloatValue:100.0]; // (0 <= percent <= 100 ).  Default: 100.0
	[self takePercent:mPercentSlider];

	//TODO: [mEnergyCombo selectItemAtIndex:0];
	[mResizeOrderCombo selectItemAtIndex:0];

	[mBrushSizeSlider setFloatValue:10.0];
	[mBrushWeightSlider setFloatValue:1.0];
	[self setupImageSize];
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
	#else
	NSDictionary *options;
    NSImage *img;

    img = [NSImage imageNamed: @"image broken"];
    options = [NSDictionary dictionaryWithObjectsAndKeys:
          @"0.1", @"Version",
          @"Liquid Rescale", @"ApplicationName",
          img, @"ApplicationIcon",
          @"Copyright 2009, Valery Brasseur", @"Copyright",
          @"Liquid Rescale v0.1 prealpha", @"ApplicationVersion",
          nil];

    [[NSApplication sharedApplication] orderFrontStandardAboutPanelWithOptions:options];
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


#if 0
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
	int theValue = (int)[sender floatValue];
	[mHeightTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mHeightSlider setFloatValue:theValue];
	if([mMaintainAspectButton state]==NSOnState) {
                //MLogString(1 ,@"maitingin ratio");
		NSSize imSize = [_image size];
		double pval = (theValue / (double)imSize.height);
		int neww = (pval * imSize.width);
		[mWidthTextField setFloatValue:neww];
		[mWidthSlider setFloatValue:neww];
        }
}

- (IBAction) takeSteps: (id)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	int theValue = (int)[sender floatValue];
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
	int theValue = (int)[sender floatValue];
	[mWidthTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mWidthSlider setFloatValue:theValue];

	if([mMaintainAspectButton state]==NSOnState) {
                //MLogString(1 ,@"maitingin ratio");
		NSSize imSize = [_image size];
		double pval = (theValue / (double)imSize.width);
		int newh = (pval * imSize.height);
		[mHeightTextField setFloatValue:newh];
		[mHeightSlider setFloatValue:newh]; 
        }
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
    if (cancelscaling == YES) {
		//[LiquidRescaleTask stopProcess];
		// Release the memory for this wrapper object
		//[LiquidRescaleTask release];
		//LiquidRescaleTask=nil;
    }
#ifndef GNUSTEP
	// 10.5 ? RestoreApplicationDockTileImage();
#endif
    [NSApp terminate:nil];
    return YES;
}

- (void)setupImageSize;
{
        NSSize imSize = [_image size];
	[mHeightSlider setMaxValue:2*imSize.height];
	[mHeightSlider setFloatValue:imSize.height]; //
	[self takeHeight:mHeightSlider];
	[mWidthSlider setMaxValue:2*imSize.width];
	[mWidthSlider setFloatValue:imSize.width]; //
	[self takeWidth:mWidthSlider];
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
		//CFDataRef bits;
		NSString *text;
#ifdef GNUSTEP
		// create and configure a new Image
		image =[[NSImage alloc] initWithContentsOfFile:fileName];
		// create a meaning full info ...

		//NSBitmapImageRep *rep =[image bestRepresentationForDevice:nil];
		NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
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
				/* kCGImagePropertyExifFocalLength kCGImagePropertyExifRigidityTime kCGImagePropertyExifRigidityTime */
			}  else {
				text = @"no exif";
			}
			image = [self createThumbnail:source];
			//bits = CGDataProviderCopyData(CGImageGetDataProvider(source));
			//CFRelease(source);
			CFRelease(properties);
		} else {
			text = [fileName lastPathComponent];
		}        
#endif
#ifdef GNUSTEP		
		//NSLog(@"Exif Data in  %@", exifDict);
		// TODO better with ImageIO
		if (exifDict != nil) {
			NSNumber *expo = [exifDict valueForKey:@"ExposureTime"];
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
		//[self buildPreview];
		_image = [[NSImage alloc] initWithContentsOfFile:fileName];//[image retain];
		[self setupImageSize];
		//[newImage release]; // memory bug ?
		[_panelImageView reloadImage];

		// TODO: better interface ?
		  // TODO: this part should be done on load ...
		
		  int             Bpr;
		 // int             spp;
		  int             w;
		  int             h;
		  const unsigned char  *pixels;
#ifndef GNUSTEP
			CGImageRef cgiref = CGImageSourceCreateImageAtIndex(source, 0, NULL);
			w = CGImageGetWidth( cgiref );
			h = CGImageGetHeight( cgiref );
			Bpr = CGImageGetBytesPerRow(cgiref);
			
			CFDataRef imageData = CGDataProviderCopyData( CGImageGetDataProvider( cgiref ));
			pixels = (const unsigned char  *)CFDataGetBytePtr(imageData);
#else
			
		  Bpr =[rep bytesPerRow];
		  //spp =[rep samplesPerPixel];
		  w =[rep pixelsWide];
		  h =[rep pixelsHigh];
		  pixels =[rep bitmapData];
#endif
		// TODO: use a progress window ?
		  unsigned char* img_bits = (unsigned char*)malloc(w*h*3);
		    int x,y;
		  for (y=0; y<h; y++) {
		       unsigned char *p = (unsigned char *)(pixels + Bpr*y);
		       unsigned char* _imptr = img_bits + y * w * 3;
		       for (x=0; x<w; x++/*,p+=spp*/) {
				// maybe we should use the alpha plane here ...
				_imptr[3*x] = p[3*x];
				_imptr[3*x+1] =p[3*x+1];
				_imptr[3*x+2] = p[3*x+2];
		       }
		   }

		/* (I.1) swallow the buffer in a (minimal) LqrCarver object
		  *       (arguments are width, height and number of colour channels) */
		carver = lqr_carver_new(img_bits, w, h, 3);

		// TODO: is it needed ?
		// Ask Lqr library to preserve our picture
		lqr_carver_set_preserve_input_image(carver);
		#ifndef GNUSTEP
		// TODO: check CFRelease(pixels);
		CFRelease(source);
		#endif
		
		}
	}
}


#pragma mark -
#pragma mark TODO

- (void)saveAsPanelDidEnd:(NSSavePanel *)savePanel
                  returnCode:(int)returnCode
                 contextInfo:(void *)contextInfo;
{
#pragma unused(contextInfo)
        if(returnCode == NSOKButton) {
                NSString *path = [savePanel filename];
                [savePanel close];
		MLogString(1 ,@"selected file : %@",path);
#if 0
	if([extension isEqualTo:@"jpg"]||[extension isEqualTo:@"jpeg"])
		imageData = [imageRep representationUsingType:NSJPEGFileType properties:nil];
	else if([extension isEqualTo:@"tif"]||[extension isEqualTo:@"tiff"])
		imageData = [imageRep representationUsingType:NSTIFFFileType properties:nil];
	else if([extension isEqualTo:@"bmp"])
		imageData = [imageRep representationUsingType:NSBMPFileType properties:nil];
	else if([extension isEqualTo:@"png"])
		imageData = [imageRep representationUsingType:NSPNGFileType properties:nil];
	else if([extension isEqualTo:@"gif"])
		imageData = [imageRep representationUsingType:NSGIFFileType properties:nil];

	//[props setObject:[NSNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor];
	//NSMutableDictionary *props = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.9]
	//                              forKey:NSImageCompressionFactor];
	//[props setObject:exifDict forKey:NSImageEXIFData];
	//NSData *photoData = [destImageRep representationUsingType:NSJPEGFileType properties:props];
	// NSImageColorSyncProfileData
#endif	
		NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[_rescaleImage TIFFRepresentation]];
		NSData *photoData = [rep representationUsingType:NSTIFFFileType properties:NULL];
		BOOL status = [photoData writeToFile:path atomically:YES];
		if(status)
                       NSRunInformationalAlertPanel(@"Write Complete.",
                                        @"save to %@ done",LS_OK,nil,nil,path);
                else
                        NSRunInformationalAlertPanel(@"Write Failed.",
                                        @"save to %@ failed",LS_OK,nil,nil,path);
	}
}

- (IBAction)saveDocumentAs:(id)sender
{
#pragma unused(sender)
	MLogString(1 ,@"");
	if (_rescaleImage != NULL) {
		NSSavePanel *panel = [NSSavePanel savePanel];
		[panel setAlphaValue:0.95];
		[panel setCanCreateDirectories:NO];
		//[panel setRequiredFileType:@"tiff"];
		//TODO: [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"tiff","jpeg",nil]];
		[panel setCanSelectHiddenExtension:YES]; // is it needed ?
		[panel beginSheetForDirectory:nil
				 file:@"unnamed.tif"
			   modalForWindow:window
				modalDelegate:self
			   didEndSelector:@selector(saveAsPanelDidEnd:returnCode:contextInfo:)
				  contextInfo:NULL];
	} else {
              NSRunCriticalAlertPanel ([[NSProcessInfo processInfo] processName],
			NSLocalizedString(@"Rescale Not Done",@""), 
			LS_OK, NULL, NULL);
	}
}

// TODO: better ?
- (IBAction) saveDocument: (id) sender
{
	if (_rescaleImage != NULL) {
		[self saveDocumentAs:sender];
	} else {
              NSRunCriticalAlertPanel ([[NSProcessInfo processInfo] processName],
			NSLocalizedString(@"Rescale Not Done",@""), 
			LS_OK, NULL, NULL);
	}
}

#pragma mark -
#pragma mark Mask I/O

- (void)openMaskPanelDidEnd:(NSOpenPanel *)openPanel
                  returnCode:(int)returnCode
                 contextInfo:(void *)contextInfo;
{
#pragma unused(contextInfo)
        if(returnCode == NSOKButton) {
                NSString *path = [openPanel filename];
                [openPanel close];
		MLogString(1 ,@"selected file : %@",path);

                _imageMask =[[NSImage alloc] initWithContentsOfFile:path];

		// DEBUG...
		NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[_imageMask TIFFRepresentation]];
		int Bpr =[rep bytesPerRow];
                int spp =[rep samplesPerPixel];
                int  w =[rep pixelsWide];
                int  h =[rep pixelsHigh];
		MLogString(1 ,@"mask : (%d,%d) channel : %d (alpha: %d)",w,h,spp,[rep hasAlpha]);
		[_imageView setMaskImage:_imageMask];
	}
}

- (IBAction) openMask: (id) sender
{
	MLogString(1 ,@"");
        // Create the File Open Panel class.
        NSOpenPanel* oPanel = [NSOpenPanel openPanel];

        [oPanel setCanChooseDirectories:NO];
        [oPanel setCanChooseFiles:YES];
        [oPanel setCanCreateDirectories:YES];
        [oPanel setAllowsMultipleSelection:NO];
        [oPanel setAlphaValue:0.95];
        [oPanel setTitle:@"Select a mask to use"];
	[oPanel beginSheetForDirectory:nil
		file:nil // TODO: better naming ?
		modalForWindow:window
		modalDelegate:self
		didEndSelector:@selector(openMaskPanelDidEnd:returnCode:contextInfo:)
				  contextInfo:NULL];
}

- (void)saveMaskPanelDidEnd:(NSSavePanel *)savePanel
                  returnCode:(int)returnCode
                 contextInfo:(void *)contextInfo;
{
#pragma unused(contextInfo)
        if(returnCode == NSOKButton) {
                NSString *path = [savePanel filename];
                [savePanel close];
                MLogString(1 ,@"selected file : %@",path);
                NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[_imageMask TIFFRepresentation]];
                NSData *photoData = [rep representationUsingType:NSPNGFileType properties:NULL];
                BOOL status = [photoData writeToFile:path atomically:YES];
                if(status)
                       NSRunInformationalAlertPanel(@"Write Mask Complete.",
                                        @"save to %@ done",LS_OK,nil,nil,path);
                else
                        NSRunInformationalAlertPanel(@"Write Mask Failed.",
                                        @"save to %@ failed",LS_OK,nil,nil,path);
        }
}

- (IBAction) saveMask: (id)sender;
{
#pragma unused(sender)
        MLogString(1 ,@"");
        if (_imageMask != NULL) {
                NSSavePanel *panel = [NSSavePanel savePanel];
		[panel setAlphaValue:0.95];
                [panel setCanCreateDirectories:NO];
                [panel setRequiredFileType:@"png"];
                [panel setCanSelectHiddenExtension:YES]; // is it needed ?
                [panel beginSheetForDirectory:nil
                                 file:@"unnamed.png" // TODO: good name
                           modalForWindow:window
                                modalDelegate:self
                           didEndSelector:@selector(saveMaskPanelDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
        } else {
              NSRunCriticalAlertPanel ([[NSProcessInfo processInfo] processName],
                        NSLocalizedString(@"No Image Mask Created",@""),
                        LS_OK, NULL, NULL);
        }
}

#pragma mark -
#pragma mark mask handling 

// select tool to draw on the mask
- (IBAction) setBrushMask: (id)sender;
{
	NSButtonCell *selCell = [sender selectedCell];
	MLogString(1 ,@"Selected cell is %d", [selCell tag]);

}

- (IBAction) setMaskTool: (id)sender;
{
	int selectedSegment = [sender selectedSegment];
	MLogString(1 ,@"Selected cell is %d", selectedSegment);
}

// clear the mask ...
- (IBAction) resetMask: (id)sender;
{
	MLogString(1 ,@"");
	
	if (_imageMask != NULL) 
		[_imageMask release];
	
	NSSize imSize = [_image size];
	_imageMask = [[ NSImage alloc ] initWithSize:imSize];
	[_imageView setMaskImage:_imageMask];
}

#pragma mark -
#pragma mark output handling 

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

#pragma mark < Accessors >

-(double)zoomFactor;
{
        return _zoomfactor;
}

-(void)setZoomFactor:(double)factor;
{
        if (_zoomfactor != factor)
                _zoomfactor = factor;
}

#pragma mark <AppDataSource>

- (NSSize) imagePanelViewImageSize:(NSView*)imageView;
{
        NSLog(@"%s",__PRETTY_FUNCTION__);
        return [_image size];
}

- (NSImage*) imagePanelViewImageThumbnail:(NSView*)imageView withSize:(NSSize)size;
{
        NSLog(@"%s",__PRETTY_FUNCTION__);
        return _image;
}

#pragma mark <AppDelegate>
#pragma mark Panel

- (void) imagePanelViewSelectionDidChange:(NSView*)imageView;
{
        NSPoint anchor = [(ImagePanelView*)imageView anchor];
        //NSLog(@"%s new sel : %f %f",__PRETTY_FUNCTION__,anchor.x,anchor.y);

        // get the crop
        double percent = 100.0 / [self zoomFactor];
        NSSize viewsize = [_imageView frame].size;
        NSRect selrect = NSMakeRect(
                anchor.x,anchor.y,
                viewsize.width*percent,viewsize.height*percent);
        NSImage* imgcrop = [_image imageFromRect:selrect];
        //[_imageView setImageScaling:NSScaleProportionally];
        [_imageView setBeforeImage: imgcrop];
        //[imgcrop release];
	if (_rescaleImage) {
		NSLog(@"%s need to set after image",__PRETTY_FUNCTION__);
	}
	if (_imageMask) {
		//NSLog(@"%s need to set mask image",__PRETTY_FUNCTION__);
		NSImage* imgcrop = [_imageMask imageFromRect:selrect];
		[_imageView setMaskImage: imgcrop];
	}
}

#pragma mark Display

- (void) brushShapeCenterAt:(NSPoint)pt
{
        double mRadius = [mBrushSizeSlider doubleValue];
	double mWeight = [mBrushWeightSlider doubleValue];
	MLogString(1 ,@"radius : %f w: %f",mRadius, mWeight);
	// Create the shape of the tip of the brush. Code currently assumes the bounding
	//      box of the shape is square (height == width)
	NSRect mainOval = { { pt.x, pt.y } , { 2 * mRadius, 2 * mRadius } };


	switch ([mMaskToolButton selectedSegment]) {
	case 0 : // retain
		[_retainColor set];
		break;
	case 1 : // removal
		[_removalColor set];
		break;
	case 3 : // clear
		[_clearColor set];
		break;
	}

	[[NSBezierPath bezierPathWithOvalInRect:mainOval] fill];

}

- (float)stampBrushfrom:(NSPoint)startPoint 
	to:(NSPoint)endPoint leftOverDistance:(float)leftOverDistance
{
        // Set the spacing between the stamps. By trail and error, I've
        //      determined that 1/10 of the brush width (currently hard coded to 20)
        //      is a good interval.
        //float spacing = CGImageGetWidth(mask) * 0.1;
        float spacing = [mBrushSizeSlider doubleValue] * 0.1;

        // Anything less that half a pixel is overkill and could hurt performance.
        if ( spacing < 0.5 )
                spacing = 0.5;

        // Determine the delta of the x and y. This will determine the slope
        //      of the line we want to draw.
        float deltaX = endPoint.x - startPoint.x;
        float deltaY = endPoint.y - startPoint.y;

        // Normalize the delta vector we just computed, and that becomes our step increment
        //      for drawing our line, since the distance of a normalized vector is always 1
        float distance = sqrt( deltaX * deltaX + deltaY * deltaY );
        float stepX = 0.0;
        float stepY = 0.0;
        if ( distance > 0.0 ) {
                float invertDistance = 1.0 / distance;
                stepX = deltaX * invertDistance;
                stepY = deltaY * invertDistance;
       }

        float offsetX = 0.0;
        float offsetY = 0.0;

        // We're careful to only stamp at the specified interval, so its possible
        //      that we have the last part of the previous line left to draw. Be sure
        //      to add that into the total distance we have to draw.
        float totalDistance = leftOverDistance + distance;

        // While we still have distance to cover, stamp
        while ( totalDistance >= spacing ) {
                // Increment where we put the stamp
                if ( leftOverDistance > 0 ) {
                        // If we're making up distance we didn't cover the last
                        //      time we drew a line, take that into account when calculating
                        //      the offset. leftOverDistance is always < spacing.
                        offsetX += stepX * (spacing - leftOverDistance);
                        offsetY += stepY * (spacing - leftOverDistance);

                        leftOverDistance -= spacing;
                } else {
                        // The normal case. The offset increment is the normalized vector
                        //      times the spacing
                        offsetX += stepX * spacing;
                        offsetY += stepY * spacing;
                }

                // Calculate where to put the current stamp at.
                NSPoint stampAt = NSMakePoint(startPoint.x + offsetX, startPoint.y + offsetY);

                // Ka-chunk! Draw the image at the current location
                [self brushShapeCenterAt:stampAt];

                // Remove the distance we just covered
                totalDistance -= spacing;
        }

        // Return the distance that we didn't get to cover when drawing the line.
        //      It is going to be less than spacing.
        return totalDistance;
}

- (void) imageDisplayViewMouseDown:(NSEvent*)event inView:(NSView*)view;
{
	MLogString(1 ,@"");
	if (_imageMask != nil ) {
		NSPoint loc = [view convertPoint:[event locationInWindow] fromView:view];

		//NSLog(@"%s loc sel : %f %f",__PRETTY_FUNCTION__,loc.x,loc.y);
		NSPoint anchor = [_panelImageView anchor];
		//NSLog(@"%s anchor sel : %f %f",__PRETTY_FUNCTION__,anchor.x,anchor.y);
		loc.x += anchor.x;
		loc.y += anchor.y;
		//NSLog(@"%s loc sel after : %f %f",__PRETTY_FUNCTION__,loc.x,loc.y);

		[_imageMask lockFocus];
		[NSGraphicsContext saveGraphicsState];

		[self brushShapeCenterAt:loc];	

		[NSGraphicsContext restoreGraphicsState];
		[_imageMask unlockFocus];

	        mLastPoint = loc;
        	mLeftOverDistance = 0.0;

		// very inefficient
		[view setNeedsDisplay:YES];
	}
}

- (void) imageDisplayViewMouseDragged:(NSEvent*)event inView:(NSView*)view;
{
	MLogString(1 ,@"");
	if (_imageMask !=  NULL) {
		NSPoint loc = [view convertPoint:[event locationInWindow] fromView:view];

		NSPoint anchor = [_panelImageView anchor];
		//NSLog(@"%s anchor sel : %f %f",__PRETTY_FUNCTION__,anchor.x,anchor.y);
		loc.x += anchor.x;
		loc.y += anchor.y;

		[_imageMask lockFocus];
		[NSGraphicsContext saveGraphicsState];

		//[self brushShapeCenterAt:loc];	
		mLeftOverDistance = [self stampBrushfrom:mLastPoint to:loc leftOverDistance:mLeftOverDistance];

		[NSGraphicsContext restoreGraphicsState];
		[_imageMask unlockFocus];

		mLastPoint = loc;
		// very inefficient
		[view setNeedsDisplay:YES];
	}
}

- (void) imageDisplayViewMouseUp:(NSEvent*)event inView:(NSView*)view;
{
	MLogString(1 ,@"");
	if (_imageMask !=  NULL) {
		NSPoint loc = [view convertPoint:[event locationInWindow] fromView:view];
		NSPoint anchor = [_panelImageView anchor];
		//NSLog(@"%s anchor sel : %f %f",__PRETTY_FUNCTION__,anchor.x,anchor.y);
		loc.x += anchor.x;
		loc.y += anchor.y;

		[_imageMask lockFocus];
		[NSGraphicsContext saveGraphicsState];

		// Stamp the brush in a line, from the last mouse location to the current one
		mLeftOverDistance = [self stampBrushfrom:mLastPoint to:loc leftOverDistance:mLeftOverDistance];

		[NSGraphicsContext restoreGraphicsState];
		[_imageMask unlockFocus];

		mLastPoint = NSZeroPoint;
		mLeftOverDistance = 0.0;

		// very inefficient
		[view setNeedsDisplay:YES];
	}
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
#if 0			
              [standardUserDefaults setObject:[mOuputFile stringValue] forKey:@"outputDirectory"];
              [standardUserDefaults setObject:[mOutFile stringValue] forKey:@"outputFile"];
              [standardUserDefaults setObject:[mAppendTo stringValue] forKey:@"outputAppendTo"];
              [standardUserDefaults setObject:[mOutQuality stringValue] forKey:@"outputQuality"];
#endif	
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
		
        if( result == NSAlertDefaultReturn ) {
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

- (void) progress_init:(NSString*)message;
{
  MLogString(1 ,@"msg: %@", message);
  [mProgressIndicator setUsesThreadedAnimation:YES];
  //[mProgressIndicator setIndeterminate:YES];
  if (!_stage)
        [mProgressIndicator setDoubleValue:0.0];
    else
	[mProgressIndicator setDoubleValue:50.0];

  [mProgressIndicator setMaxValue:100.0]; 
  [mProgressIndicator startAnimation:self];
  [mProgressText setStringValue:message];
#ifdef GNUSTEP
	[mProgressIndicator displayIfNeeded];
#endif
}

- (void) progress_update:(NSNumber*)percent;
{
	//MLogString(1 ,@"percent: %@", percent);
	int m_progress;

	if (!_stage) {
		if (!_wResize || !_hResize)
		    m_progress = (int)([percent doubleValue]*100.0);
		else
		    m_progress = (int)([percent doubleValue]*50.0);
	} else {
		m_progress = (int)(50.0 + [percent doubleValue]*50.0);
        }

  [mProgressIndicator setDoubleValue:m_progress];
  [myBadge badgeApplicationDockIconWithProgress:(m_progress/100.0) insetX:2 y:3];
  //[mProgressText setStringValue:percent];
  //MLogString(1 ,@"percent: %d", m_progress);
  //NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
#ifdef GNUSTEP
	[mProgressIndicator displayIfNeeded];
#endif
}


- (void) progress_end:(NSString*)message;
{
	MLogString(1 ,@"msg: %@", message);
	if (!_stage) {
		if (!_wResize || !_hResize) {
		    [mProgressIndicator setDoubleValue:0];
		    [mProgressIndicator stopAnimation:self];
#ifndef GNUSTEP
			// 10.5 RestoreApplicationDockTileImage();
#endif
		}
        else
            [mProgressIndicator setDoubleValue:50];

        _stage = YES;
    }
    else
    {
        [mProgressIndicator setDoubleValue:0];
	[mProgressIndicator stopAnimation:self];
#ifndef GNUSTEP
	// 10.5 RestoreApplicationDockTileImage();
#endif
    }
    [mProgressText setStringValue:message];
#ifdef GNUSTEP
	[mProgressIndicator displayIfNeeded];
#endif
// TODO: int req = [NSApp requestUserAttention:NSInformationalRequest];
//	cancelUserAttentionRequest
// note : in 10.5 :
/* 
 * NSDockTile *tile = [[NSApplication sharedApplication] dockTile];
 * [tile setBadgeLabel:@"Lots"];
 */

}

- (void) buildSkinToneBias;
{
	MLogString(1 ,@"");
	int             Bpr;
	// int             spp;
	int             w;
	int             h;
	const unsigned char  *pixels;
//#ifndef GNUSTEP
#if 0
	CGImageRef cgiref = CGImageSourceCreateImageAtIndex(source, 0, NULL);
	w = CGImageGetWidth( cgiref );
	h = CGImageGetHeight( cgiref );
	Bpr = CGImageGetBytesPerRow(cgiref);

	CFDataRef imageData = CGDataProviderCopyData( CGImageGetDataProvider( cgiref ));
	pixels = (const unsigned char  *)CFDataGetBytePtr(imageData);
#else
	NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[_image TIFFRepresentation]];
	Bpr =[rep bytesPerRow];
        //spp =[rep samplesPerPixel];
        w =[rep pixelsWide];
        h =[rep pixelsHigh];
        pixels =[rep bitmapData];
#endif
	int x,y;

        for (y=0; y<h; y++) {
            unsigned char *p = (unsigned char *)(pixels + Bpr*y);
            for (x=0; x<w; x++/*,p+=spp*/) {
                  // maybe we should use the alpha plane here ...
		  gdouble bias = 10000.0*isSkinTone(p[3*x],p[3*x+1],p[3*x+2]);
		  lqr_carver_bias_add_xy(carver,bias,x,y);
             }
        }
}
@end
