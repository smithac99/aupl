//
//  PlayQueue.m
//  aupl
//
//  Created by Alan Smith on 31/12/2019.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import "PlayQueue.h"
@interface PlayQueue()
{
    NSTimeInterval dispatchToken;
}
@property (weak) IBOutlet NSTextField *mainSongLabel;
@property (weak) IBOutlet NSTextField *mainArtistAlbumLabel;
@property (weak) IBOutlet NSTextField *elapsedLabel;
@property (weak) IBOutlet NSTextField *toGoLabel;
@property (weak) IBOutlet NSSlider *timeSlider;


@end

@implementation PlayQueue

-(instancetype)init
{
    if (self = [super init])
    {
        _queue = [NSMutableArray array];
        _historyQueue = [NSMutableArray array];
    }
    return self;
}

-(void)awakeFromNib
{
    [self resetLabels];
    [super awakeFromNib];
}

-(void)resetLabels
{
    [self.mainSongLabel setStringValue:@""];
    [self.mainArtistAlbumLabel setStringValue:@""];
    [self.elapsedLabel setStringValue:@"0:00"];
    [self.toGoLabel setStringValue:@"-0:00"];
    [self.timeSlider setIntValue:0];
}

-(void)updateLabelsEtc
{
    if ([_queue count] == 0)
    {
        [self resetLabels];
        return;
    }
    NSMutableDictionary *md = _queue[0];
    NSMutableDictionary *td = md[@"trackdict"];
    [self.mainSongLabel setStringValue:td[@"track"]];
    NSString *artistalbum = [NSString stringWithFormat:@"%@ - %@",td[@"artist"],td[@"album"]];
    [self.mainArtistAlbumLabel setStringValue:artistalbum];
}
-(void)stopAllPlay
{
    
}

-(void)emptyQueue
{
    [_queue removeAllObjects];
}

-(BOOL)queueEmpty
{
    return [_queue count] == 0;
}

-(void)play
{
    [self playCurrentTrack];
}

-(void)playCurrentTrack
{
    if ([_queue count] == 0)
        return;
    NSMutableDictionary *md = _queue[0];
    AuPlayer *pl = md[@"player"];
    [pl play];
}

-(NSMutableDictionary*)queueObject:(NSInteger)trackNumber
{
    NSMutableDictionary *td = [_delegate trackForIdx:trackNumber];
    NSString *path = [_delegate fullPathForRelPath:td[@"relPath"]];
    NSMutableDictionary *md = [[NSMutableDictionary alloc]initWithDictionary:@{@"trackno":@(trackNumber),
        @"fullpath":path,
                                                                               @"trackdict":td
    }];
    return md;
}
-(void)startPlayingCurrentTrack
{
    NSMutableDictionary *md = _queue[0];
    NSInteger trackNumber = [md[@"trackno"]integerValue];
    NSString *fullPath = md[@"fullpath"];
    AuPlayer *player = [[AuPlayer alloc]initWithTrackIndex:trackNumber];
    player.delegate = self;
    md[@"player"] = player;
    [player startPlaying:fullPath volume:1.0];
    [self updateLabelsEtc];
    [self startPeriodicUpdates];
}

-(BOOL)goToNext
{
    if ([_queue count] < 2)
        return NO;
    BOOL playing = [_delegate isPlaying];
    NSMutableDictionary *md = _queue[0];
    AuPlayer *pl = md[@"player"];
    [pl stopPlaying];
    [md removeObjectForKey:@"player"];
    [_historyQueue addObject:md];
    [_queue removeObjectAtIndex:0];
    if (playing)
        [self startPlayingCurrentTrack];
    return YES;
}

-(BOOL)goToPrev
{
    return YES;
}
-(void)buildQueueFrom:(NSArray*)trackNumbers
{
    [self emptyQueue];
    for (NSNumber *n in trackNumbers)
        [_queue addObject:[self queueObject:[n integerValue]]];
    [self startPlayingCurrentTrack];
}

-(void)pause
{
    if ([_queue count] == 0)
        return;
    NSMutableDictionary *md = _queue[0];
    AuPlayer *pl = md[@"player"];
    [pl pause];
    [self stopTimer];
}

-(void)track:(NSInteger)trkno finishedOK:(BOOL)ok;
{
    if ([_queue count] == 0)
        return;
    NSMutableDictionary *md = _queue[0];
    [md removeObjectForKey:@"player"];
    [_historyQueue addObject:md];
    [_queue removeObjectAtIndex:0];
    if ([_queue count] > 0)
        [self startPlayingCurrentTrack];
}

NSString *timePrint(NSTimeInterval secs)
{
    int mins = ((int)secs) / 60;
    int ss = ((int)fabs(secs)) % 60;
    return [NSString stringWithFormat:@"%d:%02d",mins,ss];
}
-(void)updateTimeLabels
{
    NSMutableDictionary *md = _queue[0];
    NSInteger durationSecs = 0;
    AuPlayer *player = md[@"player"];
    NSNumber *n = md[@"duration"];
    if (n == nil || [n integerValue] == 0)
    {
        if ([player state] == AUP_PLAYING || [player state] == AUP_PAUSED)
        {
            durationSecs = [player duration];
            if (durationSecs <= 0)
                return;
            md[@"duration"] = @(durationSecs);
        }
        else
            return;
    }
    else
        durationSecs = [n integerValue];
    NSTimeInterval cur = [player time ];
    NSTimeInterval en = durationSecs - cur;
    [self.timeSlider setFloatValue:(cur/durationSecs) * [self.timeSlider maxValue]];
    [self.elapsedLabel setStringValue:timePrint(cur)];
    [self.toGoLabel setStringValue:timePrint(-en)];

}

-(void)startPeriodicUpdates
{
    dispatchToken = [NSDate timeIntervalSinceReferenceDate];
    [self periodicUpdate:dispatchToken];
}

-(void)periodicUpdate:(NSTimeInterval)token
{
    if (token == dispatchToken)
    {
        [self updateTimeLabels];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self periodicUpdate:token];
        });
    }
}
-(void)stopTimer
{
    dispatchToken = 0;
}
@end
