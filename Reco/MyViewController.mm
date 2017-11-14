//
//  MyViewController.m
//  Reco
//
//  Created by oleg.naumenko on 10/27/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import <SEPlot/PlotView.h>

#import "MyViewController.h"
#import "Analyzer.h"


@interface MyViewController ()

@end

@implementation MyViewController
{
    Analyzer * _analyzer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSRect rect = self.view.bounds;
    PlotView * plotView = [[PlotView alloc] initWithFrame:rect];
    plotView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    [self.view addSubview:plotView];
    
    _analyzer = [Analyzer new];
    _analyzer.plotView = plotView;
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    [_analyzer stop];
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [_analyzer start];
}

@end
