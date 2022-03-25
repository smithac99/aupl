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
@import AVKit;

extern NSString *AUPL_PLAY_CHANGED;

enum
{
    AD_REFRESH_ALL_DATA = 1,
    AD_REFRESH_RETRIEVE_ROWS = 2,
    AD_REFRESH_ROW_ORDER = 4,
	AD_REFRESH_IF_ROW_COUNT_CHANGED = 8,
	AD_REFRESH_VISIBLE_ROWS = 16
};
@interface AppDelegate : NSObject <NSApplicationDelegate,NSTableViewDataSource,NSTableViewDelegate,PlayQueueDelegate,AVRoutePickerViewDelegate>

@property NSURL *rootURL;
@property NSMutableArray<NSString*> *directorySearchQueue;
@property NSMutableArray *entryList;
@property NSMutableDictionary *entryCache;
@property DBSQL *db;
@property (weak) IBOutlet NSTableView *mainTableView;
@property BOOL isPlaying;
@property IBOutlet PlayQueue *playqueue;
-(NSString*)formattedDateAndTime:(NSInteger)secsSince1970;

@end

