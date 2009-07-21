/* LiquidRescaleController */

#import <Cocoa/Cocoa.h>

@class ImagePanelView;
@class ImageDisplayView;

@interface LiquidRescaleController : NSObject 
{
  IBOutlet NSWindow *window;

  IBOutlet NSSlider* mStepsSlider;
  IBOutlet NSStepper* mStepsStepper;
  IBOutlet NSTextField* mStepsTextField;

  IBOutlet NSSlider* mRigiditySlider;
  IBOutlet NSStepper* mRigidityStepper;
  IBOutlet NSTextField* mRigidityTextField;

  IBOutlet NSSlider* mHeightSlider;
  IBOutlet NSStepper* mHeightStepper;
  IBOutlet NSTextField* mHeightTextField;

  IBOutlet NSButton* mCancelButton;
  IBOutlet NSButton* mResetButton;
  IBOutlet NSButton* mRescaleButton;

  IBOutlet NSSlider* mWidthSlider;
  IBOutlet NSStepper* mWidthStepper;
  IBOutlet NSTextField* mWidthTextField;

  IBOutlet NSSlider* mPercentSlider;
  IBOutlet NSStepper* mPercentStepper;
  IBOutlet NSTextField* mPercentTextField;

  IBOutlet NSButton* mAddWeightMaskButton;
  IBOutlet NSButton* mPreserveSkinTonesButton;
  IBOutlet NSButton* mMaintainAspectButton;

  // ouput options
  IBOutlet NSTextField *mOuputFile;
  IBOutlet NSPopUpButton *mOutFormat;
  IBOutlet NSTextField *mOutQuality;
  IBOutlet NSTextField *mOutFile;
  IBOutlet NSTextField *mAppendTo;
  IBOutlet NSMatrix *mOutputType;
  IBOutlet NSSlider *mOutputQualitySlider; 
  
  IBOutlet NSArrayController *mImageArrayCtrl;

  // open file ?
  IBOutlet NSMatrix *mDoAfter;
  
  IBOutlet ImagePanelView *_panelImageView;
  IBOutlet ImageDisplayView *_imageView;
  IBOutlet NSSlider *_zoomSlider;
   
  // metadata ... 
  IBOutlet NSButton* mCopyMeta;
  IBOutlet NSButton* mCopyAperture;
  IBOutlet NSButton* mCopyShutter;
  IBOutlet NSButton* mCopyFocal;

  IBOutlet NSPanel *mProgressPanel;
  IBOutlet NSProgressIndicator *mProgressIndicator;
  IBOutlet NSTextField *mProgressText;
 
  IBOutlet NSTableView* mTableImage;
  IBOutlet NSImageView *mPreviewImage;
  
  @private
    BOOL findRunning;
    BOOL findRunningPreview;

    NSString* _outputfile;
    NSString* _tmpfile;
    NSString* _tmppath;

    NSMutableArray *images;

    NSMutableDictionary* useroptions;
}

- (IBAction) cancel: (id)sender;
- (IBAction) reset: (id)sender;
- (IBAction) about: (id)sender;
- (IBAction) chooseOutputDirectory: (id)sender;
- (IBAction) quit: (id)sender;

- (IBAction) addImage: (id)sender;

- (IBAction) takeSteps: (id)sender;
- (IBAction) takeRigidity: (id)sender;

- (IBAction) takePercent: (id)sender;
- (IBAction) takeWidth: (id)sender;
- (IBAction) takeHeight: (id)sender;

- (IBAction) revealInFinder:(id)sender;

- (IBAction) LiquidRescale: (id)sender;

-(NSString*) outputfile;
-(void) setOutputfile:(NSString *)file;
-(NSString*) tempfile;
-(void) setTempfile:(NSString *)file;
-(NSString*) temppath;
-(void) setTempPath:(NSString *)file;

- (IBAction) openPreferences:(id)sender;

- (IBAction) openPresets: (id)sender;
- (IBAction) savePresets: (id)sender;

@end