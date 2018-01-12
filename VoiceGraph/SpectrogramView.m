//
//  SpectrogramView.m
//  Reco
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "SpectrogramView.h"

@implementation SpectrogramView

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self setup];
    }
    return self;
}

- (void) setup
{
}


- (void)setSpectrogram:(Spectrogram *)spectrogram
{
    _spectrogram = spectrogram;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {

    [super drawRect:dirtyRect];
    
    [[NSColor blackColor] setFill];
    NSRectFill(dirtyRect);
    
    if (!self.spectrogram.width || !self.spectrogram.height) return;
    
    CGFloat stepX = dirtyRect.size.width / _spectrogram.width;
    CGFloat stepY = dirtyRect.size.height / _spectrogram.height;
    NSRect cellRect = NSMakeRect(0.0, 0.0, stepX, stepY);
    
    for(int t = 0; t < _spectrogram.width; t++) {
        
        float * spectra = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:t];
//
//        printf("spectra %d\n", t);
        
        for(int f = 0; f < _spectrogram.height; f++) {
            
            float val = (spectra[f] - 7.0f)/3.0;// (float)arc4random()/UINT32_MAX;
            
//            printf("%2.2f, ", spectra[f]);
            
            NSColor * color = [NSColor colorWithWhite:val alpha:1];
            [color setFill];
            NSRectFill(cellRect);
            cellRect.origin.y += stepY;
        }
//        printf("\n\n");
        cellRect.origin.x += stepX;
        cellRect.origin.y = 0.0;
    }
}


@end
