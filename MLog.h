/*
 * a better loggin implementation
 * ideas from : http://www.borkware.com/rants/agentm/mlog/
 * and : http://www.bagelturf.com/cocoa/rwok/rwok4/index.php
*/

#import <Cocoa/Cocoa.h>

// remove any logging
// #define __BTREMOVE_LOGGING 1

// only this level and up
// #define __BTLOGGING_LEVEL 7

// use classic NSLog ...
// #define __BTFORCE_NSLOG 1

 // 0 = log everything
 // 1 = log level 1 ond obove
 // etc.
 // 7 = log nothing
#if defined(__BTREMOVE_LOGGING)
 #define MLogString(l ,s,...)
#elif defined(__BTFORCE_NSLOG)
 #define MLogString(l ,s,...) NSLog(@"%d: %@",(l),(s))
#else
 #define MLogString(l ,s,...) [MLog logFile:__FILE__ lineNumber:__LINE__ func:__PRETTY_FUNCTION__ level:l format:(s),##__VA_ARGS__]
#endif
 
@interface MLog: NSObject {
}
 
+(void)logFile:(char*)sourceFile lineNumber:(int)lineNumber func:(const char*)fname level:(int)level format:(NSString*)format,... ;
+(void)setLogMinLevel:(int)level ;
 @end

