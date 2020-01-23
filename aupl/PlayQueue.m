//
//  PlayQueue.m
//  aupl
//
//  Created by Alan Smith on 31/12/2019.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import "PlayQueue.h"
#import "AppDelegate.h"
@interface PlayQueue()
{
    NSTimeInterval dispatchToken;
    BOOL inited;
}
@property (weak) IBOutlet NSTextField *mainSongLabel;
@property (weak) IBOutlet NSTextField *mainArtistAlbumLabel;
@property (weak) IBOutlet NSTextField *elapsedLabel;
@property (weak) IBOutlet NSTextField *toGoLabel;
@property (weak) IBOutlet NSSlider *timeSlider;
@property (weak) IBOutlet NSTableView *queueTableView;

@property (weak) IBOutlet NSTableView *historyTableView;

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
    if (!inited)
    {
        inited = YES;
        _minQueueSize = 5;
        [self resetLabels];
        self.volume = 1;
        [self.volSlider setFloatValue:self.volume];
        [super awakeFromNib];
    }
}

-(void)resetLabels
{
    [self.mainSongLabel setStringValue:@""];
    [self.mainArtistAlbumLabel setStringValue:@""];
    [self.elapsedLabel setStringValue:@"0:00"];
    [self.toGoLabel setStringValue:@"-0:00"];
    [self.timeSlider setIntValue:0];
}

-(AuPlayer*)player
{
    NSMutableDictionary *md = self.currentTrack;
    return md[@"player"];

}
-(BOOL)anyThingPlaying
{
    if (self.currentTrack == nil)
        return NO;
    NSMutableDictionary *md = self.currentTrack;
    AuPlayer *pl = md[@"player"];
    return [pl isPlaying];
}

-(void)updateLabelsEtc
{
    if (self.currentTrack == nil)
    {
        [self resetLabels];
        return;
    }
    NSMutableDictionary *md = self.currentTrack;
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
    if (self.currentTrack)
        [self playCurrentTrack];
    else
        [self goToNext];
}

-(void)playCurrentTrack
{
    if (self.currentTrack == nil)
        return;
    NSMutableDictionary *md = self.currentTrack;
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
    NSMutableDictionary *md = self.currentTrack;
    NSInteger trackNumber = [md[@"trackno"]integerValue];
    NSString *fullPath = md[@"fullpath"];
    AuPlayer *player = md[@"player"];
    if (player == nil)
    {
        player = [[AuPlayer alloc]initWithTrackIndex:trackNumber];
        player.delegate = self;
        md[@"player"] = player;
    }
    [player setVolume:self.volume];
    if ([player state] < AUP_PREPARED)
        [player prepare:fullPath];
    [player play];
    [self updateLabelsEtc];
    [self startPeriodicUpdates];
    NSTimeInterval dur = [player duration];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateTrack:md startedAt:[[NSDate date]timeIntervalSince1970]];
    });
}

-(void)updateTrack:(NSMutableDictionary*)md startedAt:(NSTimeInterval)st
{
    if (md != self.currentTrack)
        return;
    NSMutableDictionary *td = md[@"trackdict"];
    td[@"lastPlayed"] = @((int)st);
    td[@"timesPlayed"] = @([td[@"timesPlayed"]integerValue]+1);
    if (td[@"durationSecs"] == nil)
    {
        AuPlayer *player = md[@"player"];
        td[@"durationSecs"] = @([player duration]);
    }
    [_delegate trackStatsUpdated:td];
}


-(void)notifyPlayStatusChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:AUPL_PLAY_CHANGED object:self userInfo:nil];
}

-(void)checkQueue
{
    if (![[NSUserDefaults standardUserDefaults]boolForKey:@"continue"])
        return;
    if ([_queue count] < _minQueueSize)
    {
        NSArray *arr = [_delegate provideMoreTracks:_minQueueSize + 5];
        [self addToQueue:arr];
    }
}

-(void)moveCurrentToHistory
{
    NSMutableDictionary *md = self.currentTrack;
    if (md)
    {
        AuPlayer *pl = md[@"player"];
        [pl stopPlaying];
        [md removeObjectForKey:@"player"];
        [_historyQueue insertObject:md atIndex:0];
        [_historyTableView reloadData];
    }
    self.currentTrack = nil;
}
-(BOOL)goToNext
{
    if ([_queue count] < 1)
    {
        [self resetLabels];
        [self notifyPlayStatusChange];
        return NO;
    }
    BOOL playing = [_delegate isPlaying];
    [self moveCurrentToHistory];
    self.currentTrack = _queue[0];
    [_queue removeObjectAtIndex:0];
    if (playing)
        [self startPlayingCurrentTrack];
    [self.queueTableView reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkQueue];
    });
    return YES;
}

-(BOOL)goToPreviousTrack
{
    if ([_historyQueue count] > 0)
    {
        NSMutableDictionary *md = _historyQueue[0];
        if (self.currentTrack)
            [_queue insertObject:self.currentTrack atIndex:0];
        self.currentTrack = md;
        [self startPlayingCurrentTrack];
        [_queueTableView reloadData];
    }
    return NO;
}

-(BOOL)goToPrev
{
    if (self.currentTrack)
    {
        AuPlayer *pl = self.currentTrack[@"player"];
        if ([pl time] > 3)
        {
            [pl setTime:0];
            return YES;
        }
    }
    return [self goToPreviousTrack];
}
-(void)buildQueueFrom:(NSArray*)trackNumbers
{
    [self emptyQueue];
    for (NSNumber *n in trackNumbers)
        [_queue addObject:[self queueObject:[n integerValue]]];
    [self.queueTableView reloadData];
}

-(void)playNext:(NSArray*)trackNumbers
{
    NSInteger i = 0;
    for (NSNumber *n in trackNumbers)
        [_queue insertObject:[self queueObject:[n integerValue]]atIndex:i++];
    [self.queueTableView reloadData];
}

-(void)addToQueue:(NSArray*)trackNumbers
{
    for (NSNumber *n in trackNumbers)
        [_queue addObject:[self queueObject:[n integerValue]]];
    [self.queueTableView reloadData];
}

-(void)pause
{
    if (self.currentTrack == nil)
        return;
    NSMutableDictionary *md = self.currentTrack;
    AuPlayer *pl = md[@"player"];
    [pl pause];
    [self stopTimer];
}

-(void)track:(NSInteger)trkno finishedOK:(BOOL)ok;
{
    if (self.currentTrack == nil)
        return;
    if (!self.stopAtEndOfThisTrack)
        [self goToNext];
    else
    {
        [self moveCurrentToHistory];
        [self updateLabelsEtc];
        self.stopAtEndOfThisTrack = NO;
        [self notifyPlayStatusChange];
    }
}

NSString *timePrint(NSTimeInterval secs)
{
    NSString *sgn = @"";
    if (secs < 0)
    {
        sgn = @"-";
        secs = -secs;
    }
    int mins = ((int)secs) / 60;
    int ss = ((int)fabs(secs)) % 60;
    return [NSString stringWithFormat:@"%@%d:%02d",sgn,mins,ss];
}
-(void)updateTimeLabels
{
    if (self.currentTrack == nil)
        return;
    NSMutableDictionary *md = self.currentTrack;
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

#pragma mark -

- (IBAction)volSliderHit:(id)sender
{
    self.volume = [sender floatValue];
    [[NSUserDefaults standardUserDefaults]setFloat:self.volume forKey:@"volume"];
    [[self player]setVolume:self.volume];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == self.queueTableView)
        return [_queue count];
    if (tableView == self.historyTableView)
        return [_historyQueue count];
    return 0;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= [_queue count])
        return nil;
    if ([[tableColumn identifier]isEqual:@"queue"])
    {
        if (rowIndex < 0 || rowIndex >= [_queue count])
            return nil;
        NSView *v = [tableView makeViewWithIdentifier:@"queue" owner:self];
        NSTextField *songf = [v viewWithTag:2];
        NSMutableDictionary *md = _queue[rowIndex];
        NSMutableDictionary *td = md[@"trackdict"];
        [songf setStringValue:td[@"track"]];
        NSString *artistalbum = [NSString stringWithFormat:@"%@ - %@",td[@"artist"],td[@"album"]];
        [[v viewWithTag:3] setStringValue:artistalbum];

        return v;
    }

    if ([[tableColumn identifier]isEqual:@"history"])
    {
        if (rowIndex < 0 || rowIndex >= [_historyQueue count])
            return nil;
        NSView *v = [tableView makeViewWithIdentifier:@"history" owner:self];
        NSTextField *songf = [v viewWithTag:2];
        NSMutableDictionary *md = _historyQueue[rowIndex];
        NSMutableDictionary *td = md[@"trackdict"];
        [songf setStringValue:td[@"track"]];
        NSString *artistalbum = [NSString stringWithFormat:@"%@ - %@",td[@"artist"],td[@"album"]];
        [[v viewWithTag:3] setStringValue:artistalbum];
        NSTextField *dt = [v viewWithTag:4];
        NSTimeInterval st = [td[@"lastPlayed"]integerValue];
        [dt setStringValue:[_delegate formattedDateAndTime:st]];
        return v;
    }

    return nil;

}

- (IBAction)removeQueueEntry:(id)sender
{
    NSIndexSet *selectedRows = [_queueTableView selectedRowIndexes];
    NSInteger clickedRow = [_queueTableView clickedRow];
    if (clickedRow == -1 || [selectedRows containsIndex:clickedRow])
    {
        [_queue removeObjectsAtIndexes:selectedRows];
    }
    else
    {
        [_queue removeObjectAtIndex:clickedRow];
    }
    [_queueTableView selectRowIndexes:[[NSIndexSet alloc]init] byExtendingSelection:NO];
    [_queueTableView reloadData];
}

@end
