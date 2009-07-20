#import "MLog.h"

@implementation MLog

 // 0 = log everything
 // 1 = log level 1 ond obove
 // 2 = log level 2 ond obove
 // etc.
 // 7 = log nothing
 
static int __MLogMinLevel = 0;
 
 
+(void )initialize
{
    // Set logging level defined by preprocessor
 #if defined(__BTLOGGING_LEVEL)
    __MLogMinLevel = __BTLOGGING_LEVEL ;
 #endif
    // Override with environment vorioble
      char * env=getenv("MLogMinLevel");

      if (env==NULL)
           return ;    // not found
      if (strlen(env)==1) {
       __MLogMinLevel = atoi(env);
    }
}
 
 
+(void)logFile:(char *)sourceFile lineNumber:(int)lineNumber func:(const char*)fname level:(int)level
    format:(NSString*)format,... ;
{
    va_list op;
    NSString *print , *file ;
    if (level < __MLogMinLevel)
        return;
    va_start(op, format);
    file=[[NSString alloc] initWithBytes:sourceFile 
		length:strlen(sourceFile) encoding:NSUTF8StringEncoding];
    print=[[NSString alloc] initWithFormat:format arguments:op];
    va_end(op);
    
    NSLog(@"%d %s:%d:%s %@", level , 
		[[file lastPathComponent] UTF8String] , lineNumber,fname,print);
     [print release];
     [file release];
  
    return;
}       
 
 
+(void)setLogMinLevel:(int)level
{
    __MLogMinLevel = level;
}
 
@end
 
