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
		volume = 0.5;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    }
    return self;
}

-(AVPlayer*)playerWithURL:(NSURL*)url
{
    AVPlayer *p = [[AVPlayer alloc]initWithURL:url];
    p.volume = [self volume];
    p.allowsExternalPlayback = YES;
    _state = AUP_PREPARED;
    [p.currentItem addObserver:self forKeyPath:@"status" options:0 context:NULL];
    return p;
}

-(void)playbackEnd:(NSNotification*)notif
{
    [_delegate track:_trackIndex finishedOK:YES];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    //[_delegate track:_trackIndex finishedOK:YES];
    NSLog(@"status change");
}

-(void)prepare:(NSString*)path
{
    self.player = [self playerWithURL:[NSURL fileURLWithPath:path]];
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
    //self.player.delegate = self;
    [self.player play];
    _state = AUP_PLAYING;
}


-(void)startPlaying:(NSString*)path volume:(float)vol
{
    if (path == nil)
        return;
    self.player = [self playerWithURL:[NSURL fileURLWithPath:path]];
    [self.player play];
    _state = AUP_PLAYING;
}

-(void)stopPlaying
{
    if (![self isPlaying])
        return;
    [self.player pause];
    _state = AUP_PAUSED;
}

-(BOOL)isPlaying
{
    return self.player && self.player.rate != 0;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    _state = AUP_FINISHED;
    [_delegate track:_trackIndex finishedOK:flag];
}

-(NSTimeInterval)duration
{
    if (self.player)
    {
        CMTime cmtime = self.player.currentItem.duration;
        return CMTimeGetSeconds(cmtime);
    }
    return 0.0;
}

-(void)setVolume:(CGFloat)f
{
    volume = f;
    self.player.volume = volume;
}

-(CGFloat)volume
{
    return volume;
}

-(NSTimeInterval)time
{
    CMTime cmtime = self.player.currentItem.currentTime;
    return CMTimeGetSeconds(cmtime);
}

-(void)setTime:(NSTimeInterval)tm
{
    CMTime cmtime = CMTimeMakeWithSeconds(tm, 600);
    [self.player seekToTime:cmtime];
}


@end
