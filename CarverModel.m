#import <Cocoa/Cocoa.h>

#import "CarverModel.h"

/*
 * object to model the carver model/information
 * needed to call the LQR API...
 */
@implementation CarverModel 

- (id) initWithUrl:(NSURL *)url;
{
}

- (void)dealloc;
{
}

#ifndef GNUSTEP
- (id) initWithCGImage:(CGImageRef)cgiref;
{
        // TODO: better interface ?
        // TODO: this part should be done on load ...

        int             Bpr;
        int             spp;
        int             w;
        int             h;
        const unsigned char  *pixels;
        size_t datalen = 0;
        LqrColDepth  coldepth = LQR_COLDEPTH_8I;
#ifndef GNUSTEP
        //CGImageRef cgiref = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        w = CGImageGetWidth( cgiref );
        h = CGImageGetHeight( cgiref );
        Bpr = CGImageGetBytesPerRow(cgiref);
        spp =  CGImageGetBitsPerPixel(cgiref)/CGImageGetBitsPerComponent(cgiref);

        MLogString(1 ,@"w: %d h: %d Bpp: %d, Bps: %d , spp: %d, Bprow: %d",w,h,
                           CGImageGetBitsPerComponent(cgiref),CGImageGetBitsPerPixel(cgiref),spp,Bpr);
        if ( Bpr != (w * h * 3 * (CGImageGetBitsPerComponent(cgiref)/8)))
               MLogString(1 ,@"is not byte align !");

        CFDataRef imageData = CGDataProviderCopyData( CGImageGetDataProvider( cgiref ));
        pixels = (const unsigned char  *)CFDataGetBytePtr(imageData);
        datalen = w * h * 3 * (CGImageGetBitsPerComponent(cgiref)/8);
        unsigned char* img_bits = (unsigned char*)malloc(datalen);
        bits = CGImageGetBitsPerComponent(cgiref);
        switch (bits) {
                case 8 :  {
                        coldepth = LQR_COLDEPTH_8I;
#if 1
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
#else
                        // TODO: better check
                        free(img_bits);
                        img_bits = pixels;
#endif

                }
                        break;
                case 16 : {
                        coldepth = LQR_COLDEPTH_16I; // better way ?

                        #if 0
                        int x,y;
                        for (y=0; y<h; y++) {
                                unsigned short *p = (unsigned short *)(pixels + Bpr*y);
                                unsigned short* _imptr = (unsigned short*)(img_bits + y * w * 6);
                                for (x=0; x<w; x++/*,p+=spp*/) {
                                        // maybe we should use the alpha plane here ...
                                        _imptr[3*x] = p[3*x];
                                        _imptr[3*x+1] =p[3*x+1];
                                        _imptr[3*x+2] = p[3*x+2];
                                }
                       }
                        #else
                        // TODO: better check
                        free(img_bits);
                        img_bits = pixels;
                        #endif
                }
                        break;
                default :
                        MLogString(1 ,@"unsupported bpp :%d !",CGImageGetBitsPerComponent(cgiref));
        }

#else

        Bpr =[rep bytesPerRow];
        spp =[rep samplesPerPixel];
        w =[rep pixelsWide];
        h =[rep pixelsHigh];
        pixels =[rep bitmapData];

        datalen = w * Bpr;
        unsigned char* img_bits = (unsigned char*)malloc(datalen);
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

#endif
        //tiff_dump(img_bits,w,h,bits, spp,"/tmp/test.tif");
        /* (I.1) swallow the buffer in a (minimal) LqrCarver object
         *       (arguments are width, height and number of colour channels) */
        carver = lqr_carver_new_ext(img_bits, w, h, spp, coldepth);

	ref_w = w;
	ref_h = h;
	depth = bits;

#ifndef GNUSTEP
        // TODO: check CFRelease(pixels);
        //CFRelease(source);
        // TODO: is it needed ?
	// yes if we did not copy ...
        // Ask Lqr library to preserve our picture
        // lqr_carver_set_preserve_input_image(carver);
#endif
}
#endif

- (NSImage*) getOuputCGImage;
{
       /**** (III) get the new data ****/
        int w = lqr_carver_get_width(carver);
        int h = lqr_carver_get_height(carver);
        MLogString(1 ,@"resizing data (%d,%d,%d) ",w,h,lqr_carver_get_channels(carver));
        // TODO: is it needed ?
        if (lqr_carver_get_channels(carver) != 3) {
                NSLog(@"bad channel number !");
                return;
        }

        // Allocate the memory for the bitmap.
        int bps = bits; // bit per sample ( 8 /16 ), get it from image !
        int destspp = 3;
    // no need on 10.4 void*   bitmapData = malloc(4*1024*768);
        //size_t bytesPerRow = (((w *(bps/ 8) * destspp)+ 0x0000000F) & ~0x0000000F); // 16 byte aligned is good
        size_t bytesPerRow = (w *(bps/ 8) * destspp);
        MLogString(1 ,@"create context bps: %d, w: %d, bpr: %d",bps,width,bytesPerRow);
        size_t datasize = h * bytesPerRow;

        unsigned char *destpix = malloc( datasize );
        if (destpix == 0) {
                MLogString(1 ,@"can't allocate memory !");
                return NULL;
        }

        unsigned char *rgb;
        int x,y;
        lqr_carver_scan_reset(carver);
        MLogString(1 ,@"bpp: %d",lqr_carver_get_col_depth(carver));
        switch (bits) {
        case 8 : {
                while (lqr_carver_scan_ext(carver, &x, &y,(void**) &rgb)) {
                        unsigned char *q = (unsigned char *)(destpix + bytesPerRow*y);
                        q[destspp*x] = rgb[0]; // red
                        q[destspp*x+1] = rgb[1]; // green
                        q[destspp*x+2] = rgb[2]; // blue
                        //q[destspp*x+3] = 255; // alpha
                }
                }
                break;
        case 16 : {
                unsigned short *rgbOut16=0;
                while (lqr_carver_scan_ext(carver, &x, &y,(void**) &rgbOut16)) {
                        unsigned short *q = (unsigned short *)(destpix + bytesPerRow*y);
                        q[destspp*x] = rgbOut16[0]; // red
                        q[destspp*x+1] = rgbOut16[1]; // green
                        q[destspp*x+2] = rgbOut16[2]; // blue
                        //q[destspp*x+3] = 65535; // alpha
                }
                }
               break;
        default :
                MLogString(1 ,@"unsupported bit depth : %d",bits);
        }

        //tiff_dump(destpix,w,h,bits, destspp,"/tmp/test.tif");

        NSBitmapImageRep *destImageRep;
#ifndef GNUSTEP
        // TODO: compilation !
        // make data provider from buffer
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, destpix, datasize, LqrProviderReleaseData);

        if (provider != NULL) {
                CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
               // TODO: better
                CGBitmapInfo bitmapInfo;
                if (bits == 16)
                        bitmapInfo = kCGBitmapByteOrder16Little; // by D. Duncan kCGBitmapByteOrderDefault | kCGImageAlphaNone;
                else
                        bitmapInfo = kCGBitmapByteOrderDefault;
                CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
                _cgrescaleref = CGImageCreate(w, h, bits,
                                                                          destspp*bits,
                                                                          bytesPerRow, colorSpaceRef, bitmapInfo,
                                                                          provider, NULL, NO, renderingIntent);
                //free (buffer); will be done by callback
        #if 0
                CGImageDestinationRef theImageSource = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:@"/tmp/io.tiff"],
                                kUTTypeTIFF,1,0);
                CGImageDestinationAddImage(theImageSource, _cgrescaleref, 0);
                BOOL status = CGImageDestinationFinalize(theImageSource);
        #endif


                // retain by quartz ...
                CGDataProviderRelease(provider);
                CGColorSpaceRelease(colorSpaceRef);
                // only 10.5 here ...
                destImageRep = [[[NSBitmapImageRep alloc] initWithCGImage:_cgrescaleref] autorelease];
                // now keep for saving
                //CGImageRelease(imageRef); //keep until ...
        }
#else
        // create a new representation without the alpha plane ...
        destImageRep = [[[NSBitmapImageRep alloc]
                                           initWithBitmapDataPlanes:&destpix
                                           pixelsWide:w
                                           pixelsHigh:h
                                           bitsPerSample:bps // [rep bitsPerSample]
                                           samplesPerPixel:destspp
                                           hasAlpha:YES
                                           isPlanar:NO
                                           colorSpaceName:NSCalibratedRGBColorSpace
                                           bytesPerRow:bytesPerRow // (spp*width)
                                           bitsPerPixel:32 ] autorelease];
#endif

        NSImage *image = [[NSImage alloc] initWithSize:[destImageRep size]];
        [image addRepresentation:destImageRep];

	return image;
}

@end

