//
//  Canvas2ImagePlugin.h
//  Canvas2ImagePlugin PhoneGap/Cordova plugin
//
//  Created by Tommy-Carlos Williams on 29/03/12.
//  Copyright (c) 2012 Tommy-Carlos Williams. All rights reserved.
//	MIT Licensed
//


#import <Cordova/CDVPlugin.h>
#import <AssetsLibrary/AssetsLibrary.h>
@interface Canvas2ImagePlugin : CDVPlugin
{
	NSString* callbackId;
    NSString *imagepath;
}

@property (nonatomic, copy) NSString* callbackId;

- (void)saveImageDataToLibrary:(CDVInvokedUrlCommand*)command;

@end
