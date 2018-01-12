//
//  ViewController.m
//  Reco-iOS
//
//  Created by oleg.naumenko on 11/14/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import "ViewController.h"
#import <SEPlot/PlotView.h>
#import "MelAnalyzer.h"

#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
{
    MelAnalyzer * _analyzer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    CGRect rect = self.view.bounds;
    
    CGFloat sbHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    rect.origin.y += sbHeight;
    rect.size.height -= sbHeight;
    //    float a = MIN(3, 5);
    //    assert(0);
    PlotView * plotView = [[PlotView alloc] initWithFrame:rect];
    plotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    plotView.scalesOverlaid = YES;
    plotView.oneTouchMovesPlot = YES;
    [plotView setWidth:30 forSide:PlotSideCount];
    [self.view addSubview:plotView];
    
    _analyzer = [MelAnalyzer new];
    _analyzer.plotView = plotView;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_analyzer start];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_analyzer stop];
}


@end
