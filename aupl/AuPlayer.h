//
//  AuPlayer.h
//  aupl
//
//  Created by Alan Smith on 31/12/2019.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN

enum
{
    AUP_NOSTATUS,
    AUP_FINISHED,
    AUP_PREPARING,
    AUP_PREPARED,
    AUP_PLAYING,
    AUP_PAUSED
};
@protocol PlayerDelegate <NSObject>

-(void)track:(NSInteger)trkno finishedOK:(BOOL)ok;

@end

@interface AuPlayer : NSObject<AVAudioPlayerDelegate>
{
	float volume;
}
@property (retain)AVPlayer *player;
@property NSInteger trackIndex;
@property (weak) id<PlayerDelegate> delegate;
@property int state;
-(instancetype)initWithTrackIndex:(NSInteger)idx;
-(void)prepare:(NSString*)path;
-(void)pause;
-(void)play;
-(void)startPlaying:(NSString*)path volume:(float)vol;
-(BOOL)isPlaying;
-(void)setVolume:(CGFloat)f;
-(CGFloat)volume;
-(void)stopPlaying;
-(NSTimeInterval)duration;
-(NSTimeInterval)time;
-(void)setTime:(NSTimeInterval)tm;


@end


NS_ASSUME_NONNULL_END
