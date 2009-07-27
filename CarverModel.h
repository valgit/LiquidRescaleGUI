#import <Cocoa/Cocoa.h>

/*
 * object to model the carver model/information
 * needed to call the LQR API...
 */
@interface CarverModel : NSObject
{
@private
  LqrCarver * carver;
  NSImage* layer_ID;

  NSURL* _url;

  int ref_w;
  int ref_h;

  int orientation;
  int depth;

  double enl_step;
}

- (id) initWithUrl:(NSURL *)url;
- (void)dealloc;

- (BOOL)render;

