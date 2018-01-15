//
//  Player.h
//  Reco
//
//  Created by oleg.naumenko on 1/15/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Player;

typedef void(^PlayerStateCallback)(Player * player);

@interface Player : NSObject

- (instancetype) initWithFilePath:(NSString*)filepath;

@property (nonatomic, readonly) NSString * filePath;
@property (nonatomic, readonly) float duration;
@property (nonatomic, readonly) float position;
@property (nonatomic, readonly) BOOL isPlaying;

@property (nonatomic, copy) PlayerStateCallback stateCallback;

- (void) play;
- (void) stop;

@end
