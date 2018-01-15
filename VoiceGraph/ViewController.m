//
//  ViewController.m
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "ViewController.h"
#import "FileAnalyser.h"
#import "SpectrogramView.h"
#import "RecorderViewController.h"
#import "Player.h"

@implementation ViewController
{
    FileAnalyser * _fileAnalyser;
    IBOutlet SpectrogramView * _spectrogramView;
    IBOutlet NSTextField * _spectrogramLabel;
    Player * _player;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    

    
}

- (void) viewDidAppear
{
    [super viewDidAppear];
    
    NSString * lastFilePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastOpenedFilePath"];
    if (lastFilePath) {
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:lastFilePath];
        if (exists) {
            [self openFileAtPath:lastFilePath];
        }
    }
    
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

}

- (IBAction)onPlayButton:(NSButton*)sender
{
    NSString * file = _fileAnalyser.filePath;
    _player = [[Player alloc] initWithFilePath:file];
    _player.stateCallback = ^(Player *player) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (player.isPlaying) {
                sender.enabled = NO;
            } else {
                sender.enabled = YES;
            }
        });
    };
    [_player play];
}

- (IBAction)onOpenButton:(NSButton*)sender
{
    NSOpenPanel * openPanel = [[NSOpenPanel alloc]init];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == 1) {
            NSString * path = openPanel.URLs.firstObject.path;
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
            if (exists) {
                [self openFileAtPath:path];
            } else {
                NSLog(@"File Does Not Exist!");
            }
        }
    }];
}

- (void) openFileAtPath:(NSString*)filePath
{
    NSLog(@"%@", filePath);
        
    _fileAnalyser = [[FileAnalyser alloc] init];
    [_fileAnalyser openFileFromPath:filePath completion:^(id result, NSError *error) {
        if (result) {
            
            NSLog(@"stream length: %@ bytes", @(_fileAnalyser.streamByteLength));
            NSLog(@"stream duration: %2.3f s", _fileAnalyser.duration);
            NSLog(@"stream sample rate: %@ Hz", @(_fileAnalyser.sampleRate));
            
            _spectrogramView.spectrogram = _fileAnalyser.spectrogram;
            NSString * label = [NSString stringWithFormat:@"%@ - %@ Hz - %2.2f s", [filePath lastPathComponent], @(_fileAnalyser.sampleRate), _fileAnalyser.duration];
            _spectrogramLabel.stringValue = label;
            [_spectrogramLabel sizeToFit];
            
            [[NSUserDefaults standardUserDefaults] setObject:filePath forKey:@"LastOpenedFilePath"];
        }
    }];
}


- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationController isKindOfClass:[RecorderViewController class]])
    {
        RecorderViewController * recVC = (RecorderViewController*) segue.destinationController;
        recVC.completion = ^(NSString *filePath, NSError *error) {
            if (filePath) {
                [self openFileAtPath:filePath];
            }
        };
    }
}


@end
