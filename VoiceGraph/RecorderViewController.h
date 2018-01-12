//
//  RecorderViewController.h
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void(^RecordCompletion)(NSString * filePath, NSError * error);

@interface RecorderViewController : NSViewController

@property (nonatomic, readonly) BOOL recording;
@property (nonatomic, copy) RecordCompletion completion;

@end
