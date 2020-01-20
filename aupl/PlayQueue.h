//
//  PlayQueue.h
//  aupl
//
//  Created by Alan Smith on 31/12/2019.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AuPlayer.h"


@protocol PlayQueueDelegate <NSObject>

-(NSMutableDictionary*)trackForIdx:(NSInteger)idx;
-(NSString*)fullPathForRelPath:(NSString*)relPath;
-(BOOL)isPlaying;
-(NSArray*)provideMoreTracks:(NSInteger)num;
-(void)trackStatsUpdated:(NSMutableDictionary*)md;

@end

@interface PlayQueue : NSObject<PlayerDelegate>
@property NSMutableArray *queue,*historyQueue;
@property NSMutableDictionary *currentTrack;
@property NSInteger minQueueSize;
@property BOOL stopAtEndOfThisTrack;
@property (weak) IBOutlet id<PlayQueueDelegate>delegate;
-(void)play;
-(void)stopAllPlay;
-(void)emptyQueue;
-(BOOL)queueEmpty;
-(void)playNext:(NSArray*)trackNumbers;
-(void)addToQueue:(NSArray*)trackNumbers;
-(void)buildQueueFrom:(NSArray*)trackNumbers;
-(BOOL)goToNext;
-(BOOL)goToPrev;
-(void)pause;
-(BOOL)anyThingPlaying;
-(AuPlayer*)player;

@end

