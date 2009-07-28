include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = LiquidRescaleGUI
LiquidRescaleGUI_OBJC_FILES = LiquidRescaleController.m  main.m   \
NSImage-ProportionalScaling.m NSFileManager-Extensions.m  \
MLog.m ImageDisplayView.m ImagePanelView.m NSImage+Cropped.m \
PasteBoardHandling.m CTProgressBadge.m

LiquidRescaleGUI_MAIN_MODEL_FILE = MainMenu.nib

LiquidRescaleGUI_LANGUAGES = English

LiquidRescaleGUI_LOCALIZED_RESOURCE_FILES = \
MainMenu.nib  \
Preferences.nib  \
ExportOptions.nib \
InfoPlist.strings 


LiquidRescaleGUI_RESOURCE_FILES = \
Info.plist\
Remove.tiff\
image_broken.png\
Add.tiff

LiquidRescaleGUI_APPLICATION_ICON = GREYCstoration.png

LiquidRescaleGUI_OBJC_LIBS = -llqr-1 -lglib-2.0
LiquidRescaleGUI_LIB_DIRS+= -L./liblqr/lib
LiquidRescaleGUI_INCLUDE_DIRS+= -I./liblqr/include/lqr-1 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include

include $(GNUSTEP_MAKEFILES)/application.make

