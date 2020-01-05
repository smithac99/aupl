//
//  PlayQueue.h
//  aupl
//
//  Created by Alan Smith on 31/12/2019.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AuPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PlayQueueDelegate <NSObject>

-(NSMutableDictionary*)trackForIdx:(NSInteger)idx;
-(NSString*)fullPathForRelPath:(NSString*)relPath;
-(BOOL)isPlaying;

@end

@interface PlayQueue : NSObject<PlayerDelegate>
@property NSMutableArray *queue,*historyQueue;
@property AuPlayer *currentPlayer,*nextPlayer;
@property (weak) IBOutlet id<PlayQueueDelegate>delegate;
-(void)play;
-(void)stopAllPlay;
-(void)emptyQueue;
-(BOOL)queueEmpty;
-(void)buildQueueFrom:(NSArray*)trackNumbers;
-(BOOL)goToNext;
-(BOOL)goToPrev;
-(void)pause;

@end

NS_ASSUME_NONNULL_END
