//
//  AppDelegate.m
//  aupl
//
//  Created by alan on 04/12/19.
//  Copyright © 2019 alancsmith. All rights reserved.
//


#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <sys/stat.h>
#import "NSMutableArray+NSMutableArray_Additions.h"
#import "NSString+OBAdditions.h"

NSString *AUPL_PLAY_CHANGED = @"AUPL_PLAY_CHANGED";

NSArray *orderableColumns;
NSString *retrievableColumns;

@interface AppDelegate ()
{
    NSInteger lastProvidedIndex;
    NSMutableArray *queuedTracks;
    NSString *searchFieldString;
}
@property NSString *sortColumn;
@property BOOL sortDescending;
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *playPauseButton;
@property (weak) IBOutlet NSTextField *trackCountLabel;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    lastProvidedIndex = -1;
	orderableColumns = @[@"artist",@"album",@"trackNumber",@"track",@"created",@"lastPlayed",@"timesPlayed",@"idx"];
	retrievableColumns = @"idx,relPath,artist,track,album,created,lastPlayed,timesPlayed";
	self.directorySearchQueue = [NSMutableArray array];
	_entryList = [[NSMutableArray alloc]init];
	_entryCache = [[NSMutableDictionary alloc]init];
	if (self.sortColumn == nil)
		self.sortColumn = orderableColumns[0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playStatusChanged:) name:AUPL_PLAY_CHANGED object:nil];
	[self chooseRootDirectoryStartAt:nil];
}

- (void)playStatusChanged:(NSNotification *)notification
{
    _isPlaying = ([_playqueue anyThingPlaying]);
    _playPauseButton.highlighted = _isPlaying;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
	DoOnDatabaseQueue(^{
		[self.db closeDB];
	});
}

-(NSString*)pathRelativeToBase:(NSString*)path
{
	NSArray *pc = [path pathComponents];
	NSArray *bc = [[self.rootURL path]pathComponents];
	pc = [pc subarrayWithRange:NSMakeRange([bc count], [pc count] - [bc count])];
	return [pc componentsJoinedByString:@"/"];
}

-(NSString*)fullPathForRelPath:(NSString*)relPath
{
    NSString *f = [self.rootURL path];
    return [f stringByAppendingPathComponent:relPath];
}

-(void)tryReplaceFilePath:(NSString*)relPath row:(NSDictionary*)restOfRow
{
	
}

-(BOOL)tryInsertFilePath:(NSMutableDictionary*)metaDataDict
{
	NSString *relpath = [self pathRelativeToBase:metaDataDict[@"filePath"]];
    metaDataDict[@"relPath"] = relpath;
    NSString *artist = metaDataDict[@"artist"];
    NSString *track = metaDataDict[@"track"];
    NSString *album = metaDataDict[@"album"];
	if (artist == nil || track == nil || album == nil)
    {
		NSLog(@"nils for %@",relpath);
    }
	if (artist == nil)
		artist = @"";
	if (track == nil)
		track = @"";
	if (album == nil)
		album = @"";
	NSString *qs = @"select idx,artist,track,album,discNumber,trackNumber,durationSecs,created,lastPlayed,timesPlayed from tracks where relPath = ? ";
	sqlite3_stmt *stmt = [self.db prepareQuery:qs withParams:@[relpath]];
	NSDictionary *row = [self.db getRow:stmt];
	[self.db closeStatement:stmt];
	if (row)
	{
		[self tryReplaceFilePath:relpath row:row];
		return NO;
	}
	else
	{
        NSInteger discNo = [metaDataDict[@"discno"]integerValue];
        NSInteger trackNo = [metaDataDict[@"trkno"]integerValue];
        NSInteger crdate = [metaDataDict[@"crdate"]integerValue];
        NSString *is1 = [NSString stringWithFormat:@"insert into tracks(relPath,artist,track,album,trackNumber,created%@)",discNo>0?@",discNumber":@""];
        NSString *is2 = [NSString stringWithFormat:@" values(?,?,?,?,?,?%@)",discNo>0?@",?":@""];
        NSMutableArray *pars = [NSMutableArray arrayWithArray:@[relpath,artist,track,album,@(trackNo),@(crdate)]];
        if (discNo > 0)
            [pars addObject:@(discNo)];
		[self.db doQuery:[is1 stringByAppendingString:is2] parameters:pars];
		return YES;
	}
}

-(NSDictionary<NSString*,NSNumber*>*)discAndTrackNoPrefixOfString:(NSString*)s
{
    NSInteger idx = 0;
    unichar c = [s characterAtIndex:idx];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableArray *arr = [NSMutableArray array];
    NSInteger n = 0;
    while (idx < [s length] && (isnumber(c) || c == '-'))
    {
        if (c == '-')
        {
            [arr addObject:@(n)];
            n = 0;
        }
        else
        {
            n = n * 10 + (c - '0');
        }
        idx++;
        if (idx < [s length])
            c = [s characterAtIndex:idx];
        else
            c = 0;
    }
    dict[@"trk"] = @(n);
    NSInteger disk = 1;
    if ([arr count] > 0)
        disk = [arr[0] integerValue];
    dict[@"disk"] = @(disk);
    dict[@"idx"] = @(idx);
    return dict;
}
-(NSInteger)numberPrefixOfString:(NSString*)s
{
    NSInteger idx = [s rangeOfString:@" "].location;
    if (idx == 2)
    {
        unichar c0 = [s characterAtIndex:0];
        unichar c1 = [s characterAtIndex:1];
        if (isnumber(c0) && isnumber(c1))
        {
            return (c0 - '0') * 10 + (c1 - '0');
        }
    }
    return -1;
}

-(NSString*)coverImagePathInDirectory:(NSString*)dirPath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *contents = [fm contentsOfDirectoryAtPath:dirPath error:nil];
	for (NSString *member in contents)
	{
		NSString *type = nil;
		NSError *err = nil;
		if ([member hasPrefix:@"cover"] || [member hasPrefix:@"Cover"])
		{
			NSString *fullPath = [dirPath stringByAppendingPathComponent:member];
			NSURL *url = [NSURL fileURLWithPath:fullPath];
			if ([url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&err])
			{
				if (UTTypeConformsTo((__bridge CFStringRef)type,(CFStringRef)@"public.image"))
				{
					return fullPath;
				}
			}
		}
	}
	return nil;
}

-(NSImage*)findDirectoryImageForTrack:(NSMutableDictionary*)trackDict
{
    NSString *filePath = [self fullPathForRelPath:trackDict[@"relPath"]];
	NSString *dirPath = [filePath stringByDeletingLastPathComponent];
	NSString *imagePath = [self coverImagePathInDirectory:dirPath];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([fm fileExistsAtPath:imagePath])
	{
		NSImage *im = [[NSImage alloc]initWithContentsOfFile:imagePath];
		return im;
	}
    return nil;
}
-(NSImage*)findImageForTrack:(NSMutableDictionary*)trackDict
{
    NSString *filePath = [self fullPathForRelPath:trackDict[@"relPath"]];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
    if (artworks && [artworks count] > 0)
    {
        AVMetadataItem *art = [artworks firstObject];

        NSData *d = (NSData*)art.value;
        NSImage *im = [[NSImage alloc]initWithData:d];
		if (im)
			return im;
    }
	return [self findDirectoryImageForTrack:trackDict];
}
- (IBAction)locateInFinder:(id)sender
{
    NSArray *indexes = [self trackIndexesToPlay];
    NSMutableArray *arr = [NSMutableArray array];
    for (NSNumber *n in indexes)
    {
        NSInteger i = [n integerValue];
        NSDictionary *track = [self trackForIdx:i];
        NSString *path = [self fullPathForRelPath:track[@"relPath"]];
        if (path)
            [arr addObject:[NSURL fileURLWithPath:path]];
    }
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:arr];
}

-(BOOL)isMusicURL:(NSURL*)url
{
	NSString *type = nil;
	NSError *err = nil;
	if ([url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&err])
		if (UTTypeConformsTo((__bridge CFStringRef)type,(CFStringRef)@"public.audio") && ![[url pathExtension]isEqualToString:@"m4p"])
			return YES;
	return NO;
}

-(BOOL)processFile:(NSString*)filePath
{
    NSLog(@"%@",filePath);
	NSURL *url = [NSURL fileURLWithPath:filePath];
	if ([self isMusicURL:url])
	{
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
		
		NSMutableDictionary *metaDataDict = [[self appleTags:asset]mutableCopy];
		metaDataDict[@"filePath"] = filePath;
		if (metaDataDict[@"track"] == nil ||metaDataDict[@"artist"] == nil ||metaDataDict[@"album"] == nil )
		{
			NSDictionary *id3d = [self readTagFromPath:filePath];
			if ([[id3d allKeys]count] > 0)
			{
				NSMutableDictionary *md = [NSMutableDictionary dictionaryWithDictionary:id3d];
				[md addEntriesFromDictionary:metaDataDict];
				metaDataDict = md;
			}
		}
		if (metaDataDict[@"trkno"] == nil || metaDataDict[@"track"] == nil)
		{
			NSString *filename = [[filePath lastPathComponent]stringByDeletingPathExtension];
			NSDictionary *dtdict = [self discAndTrackNoPrefixOfString:filename];
			metaDataDict[@"trkno"] = dtdict[@"trk"];
			metaDataDict[@"discno"] = dtdict[@"disk"];
			if (metaDataDict[@"track"] == nil)
			{
				NSInteger namest = [dtdict[@"idx"]integerValue];
				filename = [filename substringFromIndex:namest];
				if ([filename hasPrefix:@" "])
					filename = [filename substringFromIndex:1];
				metaDataDict[@"track"] = filename;
			}
			if (metaDataDict[@"album"] == nil)
			{
				NSArray *comps = [url pathComponents];
				metaDataDict[@"album"] = [comps objectAtIndex:[comps count] - 2];
			}
		}
		NSDate *crdate = nil;
		NSInteger secs1970 = 0;
		BOOL ok = [url getResourceValue:&crdate forKey:NSURLCreationDateKey error:nil];
		if (ok)
		{
			secs1970 = (NSInteger)[crdate timeIntervalSince1970];
			metaDataDict[@"crdate"] = @(secs1970);
		}
		__block BOOL inserted = NO;
		DoOnDatabaseQueue(^{
			inserted = [self tryInsertFilePath:metaDataDict];
		});
		return inserted;
	}
	return NO;
}

-(void)processQueue:(int)ct
{
    if (ct <= 0)
        NSLog(@"hit zero");
	int isrtCount = 0;
	while ([self.directorySearchQueue count] > 0 && isrtCount < 100)
	{
		NSString* dirPath = [self.directorySearchQueue firstObject];
		[self.directorySearchQueue removeObjectAtIndex:0];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSError *err;
		for (NSString *f in [fm contentsOfDirectoryAtPath:dirPath error:&err])
		{
			if (![f hasPrefix:@"."])
			{
				BOOL isDir = NO;
				NSString *fullPath = [dirPath stringByAppendingPathComponent:f];
				if ([fm fileExistsAtPath:fullPath isDirectory:&isDir])
				{
					if (isDir)
					{
						[self.directorySearchQueue addObject:fullPath];
					}
					else
					{
						[self processFile:fullPath];
						isrtCount++;
					}
				}
			}
		}
	}
    if (isrtCount > 0)
        [self refresh:AD_REFRESH_IF_ROW_COUNT_CHANGED];
    if ([self.directorySearchQueue count] > 0)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self processQueue:ct - 1];
        });
    else
        NSLog(@"search finished");
}
- (IBAction)fadeAndNext:(id)sender
{
    if (_playqueue.currentTrack && [[_playqueue player]isPlaying])
    {
        [[self playqueue]fadeOut:[[self playqueue]volume] / 10 completion:^{
            [[self playqueue]goToNext];
        }];
    }
}

- (IBAction)fullScan:(id)sender
{
    [self.directorySearchQueue addObject:[self.rootURL path]];
    [self processQueue:4000];
}

-(void)processTimeQueue
{
	if ([self.directorySearchQueue count] == 0)
		return;
	NSString* dirPath = [self.directorySearchQueue firstObject];
	[self.directorySearchQueue removeObjectAtIndex:0];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *err;
	NSMutableArray *trks = [NSMutableArray array];
	NSMutableArray *dirs = [NSMutableArray array];
	for (NSString *f in [fm contentsOfDirectoryAtPath:dirPath error:&err])
	{
		if (![f hasPrefix:@"."])
		{
			BOOL isDir = NO;
			NSString *fullPath = [dirPath stringByAppendingPathComponent:f];
			if ([fm fileExistsAtPath:fullPath isDirectory:&isDir])
			{
				if (isDir)
				{
					NSDictionary *dict = [fm attributesOfItemAtPath:fullPath error:&err];
					NSDate *d = [dict fileModificationDate];
					[dirs addObject:@[fullPath,d]];
				}
				else
				{
					if ([self isMusicURL:[NSURL fileURLWithPath:fullPath]])
						[trks addObject:fullPath];
				}
			}
		}
	}
	[dirs sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		NSDate *d1 = [obj1 objectAtIndex:1];
		NSDate *d2 = [obj2 objectAtIndex:1];
		return [d1 compare:d2];
	}];
	for (NSArray *arr in dirs)
		[self.directorySearchQueue insertObject:arr[0] atIndex:0];
	BOOL inserted = NO;
	for (NSString *path in trks)
		inserted = [self processFile:path] || inserted;
	[self refresh:AD_REFRESH_IF_ROW_COUNT_CHANGED];
	if ([trks count] > 0 && inserted == NO)
	{
		[self.directorySearchQueue removeAllObjects];
		return;
	}
    if ([self.directorySearchQueue count] > 0)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self processTimeQueue];
        });
}
- (IBAction)partialScan:(id)sender
{
    [self.directorySearchQueue addObject:[self.rootURL path]];
	[self processTimeQueue];
}

-(void)processQueue
{
    [self processQueue:100];
}
-(void)openDB
{
	if(self.rootURL)
	{
		NSString *path = [[self.rootURL path]stringByAppendingPathComponent:@"aupl"];
		[DBSQL setupSingletonWithName:path andDBScriptName:@"tables"];
		self.db = Database();
        NSInteger rowct = [self refresh:AD_REFRESH_IF_ROW_COUNT_CHANGED];
        if (rowct == 0)
        {
            [self.directorySearchQueue addObject:[self.rootURL path]];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self processQueue];
            });
        }
	}
}

-(void)chooseRootDirectoryStartAt:(NSURL*)url
{
	if (url == nil)
		url = [NSURL fileURLWithPath:NSHomeDirectory()];
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel beginSheetModalForWindow:self.window
				  completionHandler:^(NSInteger result)
	 {
		 if (result == NSModalResponseOK)
		 {
			 for (NSURL *url in [panel URLs])
				 self.rootURL = url;
			 [self openDB];
		 }
	 }];
}

-(void)trackStatsUpdated:(NSMutableDictionary*)td
{
    [_mainTableView reloadData];
    DoOnDatabase(^(DBSQL *db) {
        NSString *qs = @"update tracks set lastPlayed = ?, timesPlayed = ?, durationSecs = ? where idx = ? ";
        [self.db doQuery:qs parameters:@[td[@"lastPlayed"],td[@"timesPlayed"],td[@"durationSecs"],td[@"idx"]]];

    });
}

void swapidxes(NSMutableArray *a,NSInteger i1,NSInteger i2)
{
	if (i2 < i1)
	{
		NSInteger i = i2;
		i2 = i1;
		i1= i;
	}
	NSString* temp = a[i1];
	a[i1] = a[i2];
	a[i2] = temp;
}
-(NSArray*)columnsOrderBy:(NSString*)c1
{
	NSMutableArray *mcols = [orderableColumns mutableCopy];
	if (![c1 isEqualToString:@"artist"])
	{
        NSInteger idx= [mcols indexOfObject:c1];
        if (idx != NSNotFound)
            swapidxes(mcols, 0,idx);
    }
    if (self.sortDescending)
        [mcols replaceObjectAtIndex:0 withObject:[mcols[0] stringByAppendingString:@" desc"]];
	return mcols;
}

-(NSMutableDictionary*)retrieveRowForIdx:(NSInteger)idx
{
	NSString *qs = @"select * from tracks where idx = ? ";
	sqlite3_stmt *stmt = [self.db prepareQuery:qs withParams:@[@(idx)]];
	NSDictionary *row = [self.db getRow:stmt];
	if (row)
	{
		NSMutableDictionary *md = [row mutableCopy];
		_entryCache[@(idx)] = md;
	}
	return nil;
}

-(NSString*)searchConditionForSearch:(NSString*)search
{
    NSString *searchString = @"";
    if ([search length] > 0)
    {
        NSArray *searchArray = [search nonBlankComponentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableString *ms = [[NSMutableString alloc]init];
        NSString *conjunc = @"where" ;
        for (NSString *s in searchArray)
        {
            if (![s containsString:@"\""])
            {
                [ms appendFormat:@"%@ (artist like \"%%%%%@%%%%\" or album like \"%%%%%@%%%%\" or track like \"%%%%%@%%%%\")",conjunc,s,s,s ] ;
                conjunc = @"and";
            }
        }
        searchString = ms;
    }
    return searchString;
}

-(void)retrieveIndicesSearch
{
	NSString *st = @"select idx from tracks ";
    NSString *searchString = [self searchConditionForSearch:searchFieldString];
	NSString *orderString = [[self columnsOrderBy:self.sortColumn]componentsJoinedByString:@","];
	NSString *qs = [NSString stringWithFormat:@"%@ %@ order by %@",st,searchString,orderString];
	sqlite3_stmt *stmt = [self.db prepareQuery:qs withParams:@[]];
	NSDictionary *row = [self.db getRow:stmt];
	while (row)
	{
		[_entryList addObject:row[@"idx"]];
		row = [self.db getRow:stmt];
	}
	[self.db closeStatement:stmt];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.trackCountLabel setStringValue:[NSString stringWithFormat:@"%d tracks",(int)[self.entryList count]]];
    });

}

-(NSInteger)refresh:(int)flags
{
	if (flags & AD_REFRESH_ALL_DATA)
		[_entryCache removeAllObjects];
    BOOL shouldFetch = ((flags & (AD_REFRESH_ROW_ORDER | AD_REFRESH_RETRIEVE_ROWS)) != 0);
    if (!shouldFetch && (flags & AD_REFRESH_IF_ROW_COUNT_CHANGED))
    {
        __block NSNumber *nrct;
        NSString *query = [NSString stringWithFormat:@"%@ %@",@"select count(*) from tracks",[self searchConditionForSearch:searchFieldString]];
        DoOnDatabase(^(DBSQL *db) {
             nrct = [self.db valueFromQuery:query];
        });
        int tablect = [nrct intValue];
        shouldFetch = shouldFetch || tablect != [_entryList count];
    }
    if (shouldFetch)
    {
        NSArray *selectedTrackIndexes = [self selectedTrackIndexes];
        [_entryList removeAllObjects];
        DoOnDatabase(^(DBSQL *db) {
            [self retrieveIndicesSearch];
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mainTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
            [self.mainTableView reloadData];
            [self tryAndSelectTrackIndexes:selectedTrackIndexes];
            if ([selectedTrackIndexes count] > 0)
                [self.mainTableView scrollRowToVisible:[self.mainTableView selectedRow]];
        });
    }
    return [_entryList count];
}

-(NSMutableDictionary*)trackForIdx:(NSInteger)idx
{
	if (_entryCache[@(idx)] == nil)
	{
        DoOnDatabase(^(DBSQL *db) {
            [self retrieveRowForIdx:idx];
        });
	}
	return _entryCache[@(idx)];
}
#pragma mark
#pragma mark table stuff

-(NSString*)formattedDateAndTime:(NSInteger)secsSince1970
{
    if (secsSince1970 == 0)
        return @"";
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'-'HH:mm"];
    }
     
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:secsSince1970];

    NSString *formattedDateString = [dateFormatter stringFromDate:d];
    return formattedDateString;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(NSInteger)rowIndex
{
	if (rowIndex < 0 || rowIndex >= [_entryList count])
		return nil;
	NSInteger idx = [_entryList[rowIndex]integerValue];
    NSDictionary *d = [self trackForIdx:idx];
    NSString *ident = [aTableColumn identifier];
    if ([ident isEqualToString:@"created"])
        return [self formattedDateAndTime:[d[ident] integerValue]];
    if ([ident isEqualToString:@"lastPlayed"])
        return [self formattedDateAndTime:[d[ident] integerValue]];
	return d[ident];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (_entryList)
		return [_entryList count];
	return 0;
}

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn
{
//    self.sortColumn = [tableColumn identifier];
    NSLog(@"mouseDown %@",[tableColumn identifier]);
    //[self refresh:0];
}

-(void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
    NSLog(@"didClick %@",[tableColumn identifier]);
/*    if ([self.sortColumn isEqualToString:[tableColumn identifier]])
        self.sortDescending = !self.sortDescending;
    else
    {
        self.sortDescending = NO;
        self.sortColumn = [tableColumn identifier];
    }
    [self refresh:AD_REFRESH_ROW_ORDER];*/
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	NSArray *sds = [tableView sortDescriptors];
	if ([sds count] == 0)
		return;
	NSSortDescriptor *sd = sds[0];
	if (!([sd.key isEqualToString:self.sortColumn] && (sd.ascending != self.sortDescending)))
	{
		self.sortColumn = sd.key;
		self.sortDescending = !sd.ascending;
		if (self.db)
			[self refresh:AD_REFRESH_ROW_ORDER];
	}
    //[tableView reloadData];
}
#pragma mark -

-(NSArray*)selectedTrackIndexes
{
    NSIndexSet *selectedRows = [_mainTableView selectedRowIndexes];
    return [_entryList objectsAtIndexes:selectedRows];
}

-(void)tryAndSelectTrackIndexes:(NSArray*)trackIndexes
{
    if ([trackIndexes count] == 0)
    {
        [_mainTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        return;
    }
    NSSet *indexSet = [NSSet setWithArray:trackIndexes];
    NSMutableIndexSet *ixs = [NSMutableIndexSet indexSet];
    NSInteger i = 0;
    for (NSNumber *n in _entryList)
    {
        if ([indexSet containsObject:n])
        {
            [ixs addIndex:i];
        }
        i++;
    }
    [_mainTableView selectRowIndexes:ixs byExtendingSelection:NO];
}
-(NSArray*)trackIndexesToPlay
{
    NSIndexSet *selectedRows = [_mainTableView selectedRowIndexes];
    NSInteger clickedRow = [_mainTableView clickedRow];
    if ((clickedRow == -1 || [selectedRows containsIndex:clickedRow]) && [selectedRows count] > 0)
    {
        return [_entryList objectsAtIndexes:selectedRows];
    }
    else if (clickedRow >= 0)
    {
        return @[[_entryList objectAtIndex:clickedRow]];
    }
    return @[[_entryList objectAtIndex:0]];
}

-(void)keepQueue
{
    if (![self isRandom] && [[NSUserDefaults standardUserDefaults]boolForKey:@"continue"])
    {
        NSInteger lastRow;
        NSIndexSet *ixs = [_mainTableView selectedRowIndexes];
        if ([ixs count] > 0)
            lastRow = [ixs lastIndex];
        else
            lastRow = 0;
        queuedTracks = [[_entryList subarrayWithRange:NSMakeRange(lastRow + 1, [_entryList count] - lastRow - 1)]mutableCopy];
    }
    else
        queuedTracks = nil;

}
- (IBAction)playPauseHit:(id)sender
{
    NSUInteger modifierFlags = [[[_mainTableView window]currentEvent]modifierFlags];
    if (modifierFlags & NSEventModifierFlagOption)
    {
        if (_playqueue.currentTrack && [[_playqueue player]isPlaying])
        {
            _playqueue.stopAtEndOfThisTrack = true;
            NSControl *c = sender;
            NSButtonCell *bc = [c cell];
            //[bc setBackgroundColor:[NSColor redColor]];
            [bc setTransparent:YES];
            [[c layer]setBackgroundColor:[[NSColor colorWithRed:1 green:0.7 blue:0.7 alpha:1]CGColor]];
        }
        return;
    }
    if (!_isPlaying)
    {
        if (_playqueue.currentTrack == nil && [_playqueue.queue count] == 0)
        {
            NSArray *ns = [self trackIndexesToPlay];
            [_playqueue buildQueueFrom:ns];
            lastProvidedIndex = [[ns lastObject]integerValue];
            [self keepQueue];
            [self setIsPlaying:YES];
            [_playqueue goToNext];
        }
        else
        {
            [self setIsPlaying:YES];
            [_playqueue play];
        }
    }
    else
    {
        [_playqueue pause];
        [self setIsPlaying:NO];
    }
}
- (IBAction)play:(id)sender
{
    NSArray *ns = [self trackIndexesToPlay];
    [_playqueue buildQueueFrom:ns];
    lastProvidedIndex = [[ns lastObject]integerValue];
    [self keepQueue];
    [self setIsPlaying:YES];
    [_playqueue goToNext];
    [[NSNotificationCenter defaultCenter]postNotification:[NSNotification notificationWithName:AUPL_PLAY_CHANGED object:nil]];
}

- (IBAction)playNext:(id)sender
{
    NSArray *ns = [self trackIndexesToPlay];
    [_playqueue playNext:ns];
    lastProvidedIndex = [[ns lastObject]integerValue];
}

- (IBAction)doubleClickInTable:(id)sender
{
    [self play:nil];
}

- (IBAction)queue:(id)sender
{
    NSArray *ns = [self trackIndexesToPlay];
    [_playqueue addToQueue:ns];
    lastProvidedIndex = [[ns lastObject]integerValue];
}

- (IBAction)nextHit:(id)sender
{
    [_playqueue goToNext];
}
- (IBAction)prevHit:(id)sender
{
    [_playqueue goToPrev];
}

-(BOOL)isRandom
{
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"random"];
}

-(NSInteger)rowIndexFromTrackIndex:(NSInteger)idx
{
    NSInteger i = 0;
    for (NSNumber *n in _entryList)
    {
        if ([n integerValue] == idx)
            return i;
        i++;
    }
    return -1;
}
-(NSArray*)getRandomTracks:(NSInteger)ct
{
    NSMutableArray *arr = [NSMutableArray array];
    NSString *st = [NSString stringWithFormat:@"select idx from tracks order by random() limit %d",(int)ct];
    sqlite3_stmt *stmt = [self.db prepareQuery:st withParams:@[]];
    NSDictionary *row = [self.db getRow:stmt];
    while (row)
    {
        [arr addObject:row[@"idx"]];
        row = [self.db getRow:stmt];
    }
    [self.db closeStatement:stmt];
    return arr;
}

-(NSArray*)provideMoreTracks:(NSInteger)num
{
    if (self.db == nil)
        return @[];
    if ([self isRandom])
    {
        __block NSArray *a;
        DoOnDatabase(^(DBSQL *db) {
            a = [self getRandomTracks:num];
        });
        return a;
    }
    else
    {
        if ([queuedTracks count] > 0)
        {
            if ([queuedTracks count] < num)
                num = [queuedTracks count];
            NSArray *a = [queuedTracks subarrayWithRange:NSMakeRange(0, num)];
            [queuedTracks removeObjectsInRange:NSMakeRange(0, num)];
            return a;
        }
    }
    return @[];
}


- (void)controlTextDidChange:(NSNotification *)obj
{
    
}
- (IBAction)searchHit:(id)sender
{
    NSString *ss = [sender stringValue];
    if ([ss isEqualToString:searchFieldString])
        return;
    searchFieldString = ss;
    [self refresh:AD_REFRESH_RETRIEVE_ROWS];
    /*[_entryList removeAllObjects];
    DoOnDatabase(^(DBSQL *db) {
        [self retrieveIndicesSearch];
    });
    [_mainTableView reloadData];*/
}

static void setFields(NSString *ident,NSMutableDictionary *md,char *buffer,char *source,NSInteger maxlen)
{
    memset(buffer, 0, 32);
    strncpy(buffer, source, maxlen);
    if (strlen(buffer) > 0)
        md[@"ident"] = [[NSString alloc]initWithCString:buffer encoding:NSASCIIStringEncoding];
}
-(NSDictionary*)id3v1Tags:(NSData*)data
{
    char *bytes = (char*)[data bytes];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    char *buffer = calloc(1, 32);
    char *ptr = bytes + 3;
    setFields(@"track", dict, buffer,ptr, 30);
    ptr += 30;
    setFields(@"artist", dict, buffer,ptr, 30);
    ptr += 30;
    setFields(@"album", dict, buffer,ptr, 30);
    ptr += (4 + 28);
    if (*ptr == 0)
    {
        ptr++;
        int trkno = *ptr;
        dict[@"trkno"] = @(trkno);
    }
    free(buffer);
    return dict;
}
-(NSDictionary*)readTagFromPath:(NSString*)path
{
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data = [self readLastBytes:128 from:fh];
    if ([data length] >= 128)
    {
        char *bytes = (char*)[data bytes];
        if (memcmp(bytes, "TAG", 3) == 0)
            return [self id3v1Tags:data];
    }
    return nil;
}

-(NSData*)readLastBytes:(NSInteger)ct from:(NSFileHandle*)fh
{
    struct stat st;
    int ret = fstat(fh.fileDescriptor, &st);
    if (ret == 0)
    {
        NSInteger sz = st.st_size;
        if (sz > 128)
        {
            NSInteger offset = sz - 128;
            [fh seekToFileOffset:offset];
            return [fh readDataToEndOfFile];
        }
    }
    return nil;
}

-(NSArray*)firstNonEmptyMetaDataForKeys:(NSArray*)keys asset:(AVURLAsset*)asset
{
    for (NSString *key in keys)
    {
        NSArray *a =[AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:key keySpace:AVMetadataKeySpaceCommon];
        if ([a count] > 0)
            return a;
    }
    for (NSString *key in keys)
    {
        NSArray *a =[AVMetadataItem metadataItemsFromArray:asset.metadata withKey:key keySpace:nil];
        if ([a count] > 0)
            return a;
    }
    return @[];
}
-(NSDictionary*)appleTags:(AVURLAsset*)asset
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    //NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
    NSArray *titles = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
    NSArray *artists = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
    NSArray *albumNames = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
    //NSArray *trackNumbers = [AVMetadataItem metadataItemsFromArray:asset.metadata withKey:AVMetadataiTunesMetadataKeyTrackNumber keySpace:AVMetadataKeySpaceiTunes];

    
    if ([artists count] == 0)
    {
        artists = [self firstNonEmptyMetaDataForKeys:@[AVMetadataCommonKeyArtist,AVMetadataIdentifierID3MetadataLeadPerformer,AVMetadataIdentifierID3MetadataBand] asset:asset];
        artists = [AVMetadataItem metadataItemsFromArray:asset.metadata withKey:AVMetadataIdentifierID3MetadataLeadPerformer keySpace:AVMetadataKeySpaceID3];
        if ([artists count] == 0)
            artists = [AVMetadataItem metadataItemsFromArray:asset.metadata withKey:AVMetadataIdentifierID3MetadataBand  keySpace:AVMetadataKeySpaceID3];
    }
    AVMetadataItem *title = [titles firstObject];
    AVMetadataItem *artist = [artists firstObject];
    AVMetadataItem *albumName = [albumNames firstObject];
    if (title)
        dict[@"track"] = title.value;
    if (artist)
        dict[@"artist"] = artist.value;
    if (albumName)
        dict[@"album"] = albumName.value;
    return dict;
}

- (void)locateInMainWindow:(NSArray*)tracks
{
	NSMutableIndexSet *mixs = [NSMutableIndexSet indexSet];
	for (NSNumber *n in tracks)
	{
		NSInteger i = [self rowIndexFromTrackIndex:[n integerValue]];
		if (i >= 0)
			[mixs addIndex:i];
	}
	if ([mixs count] > 0)
	{
		[_mainTableView selectRowIndexes:mixs byExtendingSelection:NO];
		[_mainTableView scrollRowToVisible:[mixs firstIndex]];
		[[_mainTableView window]makeKeyAndOrderFront:self];
	}
}

@end
