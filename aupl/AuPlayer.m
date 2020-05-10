//
//  AuPlayer.m
//  aupl
//
//  Created by Alan Smith on 31/12/2019.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import "AuPlayer.h"

@implementation AuPlayer

-(instancetype)initWithTrackIndex:(NSInteger)idx
{
    if (self = [self init])
    {
        _trackIndex = idx;
        _state = AUP_NOSTATUS;
    }
    return self;
}
-(void)prepare:(NSString*)path
{
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *err;
    self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:&err];
    self.player.delegate = self;
	self.player.volume = [self volume];
    _state = AUP_PREPARING;
    [self.player prepareToPlay];
    _state = AUP_PREPARED;
}

-(void)pause
{
    if ([self isPlaying])
    {
        [self.player pause];
        _state = AUP_PAUSED;
    }
}

-(void)play
{                                           //requires prepare be called first
    self.player.delegate = self;
    [self.player play];
    _state = AUP_PLAYING;
}


-(void)startPlaying:(NSString*)path volume:(float)vol
{
    if (path == nil)
        return;
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *err;
    self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:&err];
    self.player.delegate = self;
    if (vol != 1.0)
        self.player.volume = vol;
    [self.player play];
    _state = AUP_PLAYING;
}

-(void)stopPlaying
{
    if (![self isPlaying])
        return;
    [self.player stop];
    _state = AUP_PAUSED;
}
-(BOOL)isPlaying
{
    return self.player && self.player.isPlaying;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    _state = AUP_FINISHED;
    [_delegate track:_trackIndex finishedOK:flag];
}

-(NSTimeInterval)duration
{
    if (self.player)
        return self.player.duration;
    return 0.0;
}

-(void)setVolume:(CGFloat)f
{
    self.player.volume = f;
}

-(CGFloat)volume
{
    return self.player.volume;
}

-(NSTimeInterval)time
{
    return self.player.currentTime;
}

-(void)setTime:(NSTimeInterval)tm
{
    self.player.currentTime = tm;
}


@end
