//
//  MotionOCR.m
//  MotionOCR
//
//  Created by Fernando Espinosa on 05/01/13.
//  Copyright (c) 2013 com.ferdev. All rights reserved.
//

#import "MotionOCR.h"

#include "baseapi.h"

#include "environ.h"
#import "pix.h"

@implementation MotionOCR

- (id)init {
  return [self initWithOptions:@{}];
}

- (id)initWithOptions:(NSDictionary*)options {
  self = [super init];

  if (self) {
      // Set up the tessdata path. This is included in the application bundle
      // but is copied to the Documents directory on the first run.
      NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      NSString *documentPath = ([documentPaths count] > 0) ? [documentPaths objectAtIndex:0] : nil;

      NSString *dataPath = [documentPath stringByAppendingPathComponent:@"tessdata"];
      NSFileManager *fileManager = [NSFileManager defaultManager];
      // If the expected store doesn't exist, copy the default store.
      if (![fileManager fileExistsAtPath:dataPath]) {
          // get the path to the app bundle (with the tessdata dir)
          NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
          NSString *tessdataPath = [bundlePath stringByAppendingPathComponent:@"tessdata"];
          if (tessdataPath) {
              [fileManager copyItemAtPath:tessdataPath toPath:dataPath error:NULL];
          }
      }

      setenv("TESSDATA_PREFIX", [[documentPath stringByAppendingString:@"/"] UTF8String], 1);

      tesseract = new tesseract::TessBaseAPI();
      tesseract->Init([dataPath cStringUsingEncoding:NSUTF8StringEncoding], [options[@"language"] UTF8String]);
  }
  return self;
}

- (void)dealloc {
    delete tesseract;
    tesseract = nil;
}

- (NSString *)scan:(id)image
{
    return [self scanImage:image usingBlock:^{
        return tesseract->GetUTF8Text();
    }];
}

- (NSString *)scanHOCR:(id)image
{
    return [self scanImage:image usingBlock:^{
        /*  Calling SetInputName may not be required for newer versions of
            Tesseract anymore.
            (see https://code.google.com/p/tesseract-ocr/issues/detail?id=463) */
        tesseract->SetInputName("");
        return tesseract->GetHOCRText(0);
    }];
}

- (NSString *)scanImage:(id)image usingBlock:(char *(^)(void))outputBlock {
    [self setTesseractImage:(CGImageRef)image];

    tesseract->Recognize(NULL);

    char* utf8Text = outputBlock();
    return [NSString stringWithUTF8String:utf8Text];
}

- (void)setTesseractImage:(CGImageRef)image
{
    free(pixels);

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

	if (width <= 0 || height <= 0)
		return;

    pixels = (uint32_t *) malloc(width * height * sizeof(uint32_t));
    memset(pixels, 0, width * height * sizeof(uint32_t));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * sizeof(uint32_t), colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    tesseract->SetImage((const unsigned char *) pixels, width, height, sizeof(uint32_t), width * sizeof(uint32_t));
}

@end
