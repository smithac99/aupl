//
//  AppDelegate.h
//  aupl
//
//  Created by alan on 04/12/19.
//  Copyright © 2019 alancsmith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DBSQL.h"
#import "PlayQueue.h"

extern NSString *AUPL_PLAY_CHANGED;

enum
{
	AD_REFRESH_ALL_DATA = 1,
	AD_REFRESH_IF_ROW_COUNT_CHANGED,
	AD_REFRESH_VISIBLE_ROWS
};
@interface AppDelegate : NSObject <NSApplicationDelegate,NSTableViewDataSource,NSTableViewDelegate,PlayQueueDelegate>

@property NSURL *rootURL;
@property NSMutableArray<NSString*> *directorySearchQueue;
@property NSMutableArray *entryList;
@property NSMutableDictionary *entryCache;
@property DBSQL *db;
@property (weak) IBOutlet NSTableView *mainTableView;
@property BOOL isPlaying;
@property IBOutlet PlayQueue *playqueue;

@end

