//
//  Canvas2ImagePlugin.m
//  Canvas2ImagePlugin PhoneGap/Cordova plugin
//
//  Created by Tommy-Carlos Williams on 29/03/12.
//  Copyright (c) 2012 Tommy-Carlos Williams. All rights reserved.
//	MIT Licensed
//

#import "Canvas2ImagePlugin.h"
#import <Cordova/CDV.h>

@implementation Canvas2ImagePlugin
@synthesize callbackId;

//-(CDVPlugin*) initWithWebView:(UIWebView*)theWebView
//{
//    self = (Canvas2ImagePlugin*)[super initWithWebView:theWebView];
//    return self;
//}

- (void)saveImageDataToLibrary:(CDVInvokedUrlCommand*)command
{
    self.callbackId = command.callbackId;
	NSData* imageData = [NSData dataFromBase64String:[command.arguments objectAtIndex:0]];
	
	UIImage* image = [[[UIImage alloc] initWithData:imageData] autorelease];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy_MM_dd_HH_mm_ss"];
    NSDate *currentdate= [[NSDate alloc] init];
    NSString *dateFromString = [dateFormatter stringFromDate:currentdate];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString* imagepath = [documentsDirectory stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"Draw%@",dateFromString ]];


//    UIImage *viewImage = image;  // --- mine was made from drawing context
//    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
//    // Request to save the image to camera roll
//    [library writeImageToSavedPhotosAlbum:[viewImage CGImage] orientation:(ALAssetOrientation)[viewImage imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error){
//        if (error) {
//            NSLog(@"error");
//        } else {
//            NSLog(@"url %@", assetURL);
//        }
//    }];  
//    [library release];
    
    //    NSData* data = UIImagePNGRepresentation(image);
//    [data writeToFile:imagepath atomically:YES];
    
//UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
	
  
    
    NSString *date = [self currentDateandTime];
    
    NSString  *imagePath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@_image.jpg",date]];
    [UIImageJPEGRepresentation(image, 1.0) writeToFile:imagePath atomically:YES];
    NSLog(@"ll%@",imagePath);
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:imagePath];
    [self.webView stringByEvaluatingJavaScriptFromString:[result toSuccessCallbackString: self.callbackId]];
}

- (NSString *)currentDateandTime
{
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MMddyyyy_HHmmssSS"];
    NSString *dateString = [dateFormat stringFromDate:today];
    [dateFormat release];
    
    return dateString;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    // Was there an error?
    if (error != NULL)
    {
        // Show error message...
        NSLog(@"ERROR: %@",error);
		CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR messageAsString:error.description];
		[self.webView stringByEvaluatingJavaScriptFromString:[result toErrorCallbackString: self.callbackId]];
    }
    else  // No errors
    {
        
       
        
        NSLog(@"info: %@", contextInfo);
        // Show message image successfully saved
        NSLog(@"IMAGE SAVED!");
		CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"Image saved"];
		[self.webView stringByEvaluatingJavaScriptFromString:[result toSuccessCallbackString: self.callbackId]];
    }
}

- (void)dealloc
{	
	[callbackId release];
    [super dealloc];
}


@end
