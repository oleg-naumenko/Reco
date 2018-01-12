//
//  SpectrogramView.h
//  Reco
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Spectrogram.h"

@interface SpectrogramView : NSView

@property (nonatomic, strong) Spectrogram * spectrogram;

@end
