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

NSString *AUPL_PLAY_CHANGED = @"AUPL_PLAY_CHANGED";

NSArray *orderableColumns;
NSString *retrievableColumns;

@interface AppDelegate ()
{
    NSInteger lastProvidedIndex;
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
	self.sortColumn = orderableColumns[0];
	retrievableColumns = @"idx,relPath,artist,track,album,created,lastPlayed,timesPlayed";
	self.directorySearchQueue = [NSMutableArray array];
	_entryList = [[NSMutableArray alloc]init];
	_entryCache = [[NSMutableDictionary alloc]init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playStatusChanged:) name:AUPL_PLAY_CHANGED object:nil];
	[self chooseRootDirectoryStartAt:nil];
}

- (void)playStatusChanged:(NSNotification *)notification
{
    _isPlaying = ([_playqueue anyThingPlaying]);
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

-(void)tryInsertFilePath:(NSDictionary*)metaDataDict
{
	NSString *relpath = [self pathRelativeToBase:metaDataDict[@"filePath"]];
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
		[self tryReplaceFilePath:relpath row:row];
	else
	{
        NSInteger discNo = [metaDataDict[@"discno"]integerValue];
        NSInteger trackNo = [metaDataDict[@"trkno"]integerValue];
        NSInteger crdate = [metaDataDict[@"crdate"]integerValue];
        NSString *is1 = [NSString stringWithFormat:@"insert into tracks(relPath,artist,track,album,trackNumber,created%@)",discNo>0?@",discNumber":@""];
        NSString *is2 = [NSString stringWithFormat:@" values(?,?,?,?,?,?%@)",discNo>0?@",?":@""];
		//[self.db beginTransaction];
        NSMutableArray *pars = [NSMutableArray arrayWithArray:@[relpath,artist,track,album,@(trackNo),@(crdate)]];
        if (discNo > 0)
            [pars addObject:@(discNo)];
		[self.db doQuery:[is1 stringByAppendingString:is2] parameters:pars];
		//[self.db commitTransaction];
        //[self refresh:0];
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
-(void)processFile:(NSString*)filePath
{
    NSLog(@"%@",filePath);
	NSURL *url = [NSURL fileURLWithPath:filePath];
	NSString *type = nil;
	NSError *err = nil;
	if ([url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&err])
	{
		if (UTTypeConformsTo((__bridge CFStringRef)type,(CFStringRef)@"public.audio"))
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
			DoOnDatabaseQueue(^{
                [self tryInsertFilePath:metaDataDict];
			});
		}
	}
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
	[self refresh:AD_REFRESH_IF_ROW_COUNT_CHANGED];
    //if ([self.directorySearchQueue count] > 0)
    if (ct > 0)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self processQueue:ct - 1];
        });
}
- (IBAction)fullScan:(id)sender
{
    [self.directorySearchQueue addObject:[self.rootURL path]];
    [self processQueue:4000];
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

-(void)retrieveIndicesSearch:(NSString*)search
{
	NSString *st = @"select idx from tracks ";
    NSString *searchString = @"";
    if ([search length] > 0)
    {
        searchString = [NSString stringWithFormat:@"where artist like \"%%%%%@%%%%\" or album like \"%%%%%@%%%%\" or track like \"%%%%%@%%%%\"",search,search,search ] ;
    }
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
    BOOL shouldFetch = ((flags & AD_REFRESH_ROW_ORDER) != 0);
    if (!shouldFetch && (flags & AD_REFRESH_IF_ROW_COUNT_CHANGED))
    {
        __block NSNumber *nrct;
        DoOnDatabase(^(DBSQL *db) {
             nrct = [self.db valueFromQuery:@"select count(*) from tracks"];
        });
        int tablect = [nrct intValue];
        shouldFetch = shouldFetch || tablect != [_entryList count];
    }
    if (shouldFetch)
    {
        [_entryList removeAllObjects];
        DoOnDatabase(^(DBSQL *db) {
            [self retrieveIndicesSearch:nil];
        });
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mainTableView reloadData];
    });
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
    if ([self.sortColumn isEqualToString:[tableColumn identifier]])
        self.sortDescending = !self.sortDescending;
    else
    {
        self.sortDescending = NO;
        self.sortColumn = [tableColumn identifier];
    }
    [self refresh:AD_REFRESH_ROW_ORDER];
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [tableView reloadData];
}
#pragma mark -

-(NSArray*)trackIndexesToPlay
{
    NSIndexSet *ixs = [_mainTableView selectedRowIndexes];
    if ([ixs count] > 0)
        return [_entryList objectsAtIndexes:ixs];
    return @[@0];
}

- (IBAction)playPauseHit:(id)sender
{
    if (!_isPlaying)
    {
        if (_playqueue.currentTrack == nil)
        {
            NSArray *ns = [self trackIndexesToPlay];
            [_playqueue buildQueueFrom:ns];
            lastProvidedIndex = [[ns lastObject]integerValue];
            [self setIsPlaying:YES];
            [_playqueue goToNext];
        }
        else
            [_playqueue play];
        [self setIsPlaying:YES];
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
    [self setIsPlaying:YES];
    [_playqueue goToNext];
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
}

-(BOOL)isRandom
{
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"random"];
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
        
    }
    return @[];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    
}
- (IBAction)searchHit:(id)sender
{
    [_entryList removeAllObjects];
    DoOnDatabase(^(DBSQL *db) {
        [self retrieveIndicesSearch:[sender stringValue]];
    });
    [_mainTableView reloadData];
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
    char *bytes = (char*)[data bytes];
    if (memcmp(bytes, "TAG", 3) == 0)
        return [self id3v1Tags:data];
    return nil;
}

-(NSData*)readLastBytes:(NSInteger)ct from:(NSFileHandle*)fh
{
    struct stat st;
    int ret = fstat(fh.fileDescriptor, &st);
    if (ret == 0)
    {
        NSInteger sz = st.st_size;
        NSInteger offset = sz - 128;
        [fh seekToFileOffset:offset];
        return [fh readDataToEndOfFile];
    }
    return nil;
}

-(NSDictionary*)appleTags:(AVURLAsset*)asset
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    //NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
    NSArray *titles = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
    NSArray *artists = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
    NSArray *albumNames = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
    //NSArray *trackNumbers = [AVMetadataItem metadataItemsFromArray:asset.metadata withKey:AVMetadataiTunesMetadataKeyTrackNumber keySpace:AVMetadataKeySpaceiTunes];

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
@end
