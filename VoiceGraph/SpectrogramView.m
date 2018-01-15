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
    
    NSBezierPath * line = [[NSBezierPath alloc] init];
    line.lineWidth = 2;
    NSPoint pt = NSZeroPoint;
    float * spectra = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:0];
    pt.y = spectra[0] * dirtyRect.size.height;
    [line moveToPoint:pt];
    for (int t = 1; t < _spectrogram.width; t++) {
        pt.x += stepX;
        float * spectra = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:t];
        pt.y = spectra[0] * dirtyRect.size.height;
        [line lineToPoint:pt];
    }
    [[NSColor redColor] setStroke];
    [line stroke];
    
    if (_spectrogram.maximas.count) {
        NSBezierPath * maxLines = [[NSBezierPath alloc] init];
        for (NSNumber * indexNum in _spectrogram.maximas) {
            
            CGFloat x = indexNum.integerValue * stepX;
            
            NSPoint btm = NSMakePoint(x, 0);
            NSPoint top = NSMakePoint(x, dirtyRect.size.height);
            [maxLines moveToPoint:btm];
            [maxLines lineToPoint:top];
        }
        maxLines.lineWidth = 2;
        [[NSColor yellowColor] setStroke];
        [maxLines stroke];
    }
    
    if (_spectrogram.minimas.count) {
        NSBezierPath * minLines = [[NSBezierPath alloc] init];
        for (NSNumber * indexNum in _spectrogram.minimas) {
            
            CGFloat x = indexNum.integerValue * stepX;
            
            NSPoint btm = NSMakePoint(x, 0);
            NSPoint top = NSMakePoint(x, dirtyRect.size.height);
            [minLines moveToPoint:btm];
            [minLines lineToPoint:top];
        }
        minLines.lineWidth = 1;
        [[NSColor orangeColor] setStroke];
        [minLines stroke];
    }
    
    if (_spectrogram.startIndex) {
        CGFloat x = _spectrogram.startIndex * stepX;
        
        NSBezierPath * startLine = [[NSBezierPath alloc] init];
        
        NSPoint btm = NSMakePoint(x, 0);
        NSPoint top = NSMakePoint(x, dirtyRect.size.height);
        [startLine moveToPoint:btm];
        [startLine lineToPoint:top];
        
        startLine.lineWidth = 2;
        [[NSColor blueColor] setStroke];
        [startLine stroke];
    }
    
    if (_spectrogram.endIndex) {
        CGFloat x = _spectrogram.endIndex * stepX;
        
        NSBezierPath * startLine = [[NSBezierPath alloc] init];
        
        NSPoint btm = NSMakePoint(x, 0);
        NSPoint top = NSMakePoint(x, dirtyRect.size.height);
        [startLine moveToPoint:btm];
        [startLine lineToPoint:top];
        
        startLine.lineWidth = 2;
        [[NSColor greenColor] setStroke];
        [startLine stroke];
    }
    
}


@end
