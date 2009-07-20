/* LiquidRescaleController */

#import <Cocoa/Cocoa.h>

@interface LiquidRescaleController : NSObject 
{
  IBOutlet NSWindow *window;
  IBOutlet NSSlider* mContrastSlider;
  IBOutlet NSStepper* mContrastStepper;
  IBOutlet NSTextField* mContrastTextField;
  IBOutlet NSSlider* mExposureSlider;
  IBOutlet NSStepper* mExposureStepper;
  IBOutlet NSTextField* mExposureTextField;
  IBOutlet NSSlider* mSaturationSlider;
  IBOutlet NSStepper* mSaturationStepper;
  IBOutlet NSTextField* mSaturationTextField;
  IBOutlet NSTableView* mTableImage;
  IBOutlet NSButton* mCancelButton;
  IBOutlet NSButton* mResetButton;
  IBOutlet NSButton* mEnfuseButton;

  IBOutlet NSSlider* mMuSlider;
  IBOutlet NSStepper* mMuStepper;
  IBOutlet NSTextField* mMuTextField;

  IBOutlet NSSlider* mSigmaSlider;
  IBOutlet NSStepper* mSigmaStepper;
  IBOutlet NSTextField* mSigmaTextField;

  // expert options ...
  IBOutlet NSTextField* mContrastWindowSizeTextField;
  IBOutlet NSTextField* mMinCurvatureTextField;
  
  // ouput options
  IBOutlet NSTextField *mOuputFile;
  IBOutlet NSPopUpButton *mOutFormat;
  IBOutlet NSTextField *mOutQuality;
  IBOutlet NSTextField *mOutFile;
  IBOutlet NSTextField *mAppendTo;
  IBOutlet NSMatrix *mOutputType;
  IBOutlet NSSlider *mOutputQualitySlider; 
  
  // autoalign options
  IBOutlet NSButton* mAutoalign;
  IBOutlet NSButton* mAssumeFisheye;
  IBOutlet NSButton* mOptimizeFOV;
  IBOutlet NSTextField* mControlPoints;
  IBOutlet NSTextField* mGridSize;
  
  IBOutlet NSArrayController *mImageArrayCtrl;

  // open file ?
  IBOutlet NSMatrix *mDoAfter;
  
  // metadata ... 
  IBOutlet NSButton* mCopyMeta;
  IBOutlet NSButton* mCopyAperture;
  IBOutlet NSButton* mCopyShutter;
  IBOutlet NSButton* mCopyFocal;

  IBOutlet NSPanel *mProgressPanel;
  IBOutlet NSProgressIndicator *mProgressIndicator;
  IBOutlet NSTextField *mProgressText;
  IBOutlet NSImageView *mPreviewImage;
  
  @private
    BOOL findRunning;
    BOOL findRunningPreview;

    NSString* _outputfile;
    NSString* _tmpfile;
    NSString* _tmppath;

    NSMutableArray *images;
	
	int value;
	
//	exportOptions* options;
	NSMutableDictionary* useroptions;
}

- (IBAction) cancel: (IBOutlet)sender;
- (IBAction) reset: (IBOutlet)sender;
- (IBAction) LiquidRescale: (IBOutlet)sender;
- (IBAction) about: (IBOutlet)sender;
- (IBAction) chooseOutputDirectory: (IBOutlet)sender;
- (IBAction) takeSaturation: (IBOutlet)sender;
- (IBAction) quit: (IBOutlet)sender;
- (IBAction) takeContrast: (IBOutlet)sender;
- (IBAction) takeExposure: (IBOutlet)sender;
- (IBAction) addImage: (IBOutlet)sender;

- (IBAction) takeSigma: (IBOutlet)sender;
- (IBAction) takeMu: (IBOutlet)sender;

- (IBAction) revealInFinder:(IBOutlet)sender;

-(NSString*)outputfile;
-(void)setOutputfile:(NSString *)file;
-(NSString*)tempfile;
-(void)setTempfile:(NSString *)file;
-(NSString*)temppath;
-(void)setTempPath:(NSString *)file;

- (IBAction)openPreferences:(id)sender;

- (IBAction) openPresets: (IBOutlet)sender;
- (IBAction) savePresets: (IBOutlet)sender;

@end
