//
//  AppDelegate.m
//  aupl
//
//  Created by alan on 04/12/19.
//  Copyright © 2019 alancsmith. All rights reserved.
//


#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>

NSArray *orderableColumns;
NSString *retrievableColumns;

@interface AppDelegate ()
@property NSString *sortColumn;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	orderableColumns = @[@"artist",@"album",@"track",@"lastPlayed",@"timesPlayed",@"idx"];
	self.sortColumn = orderableColumns[0];
	retrievableColumns = @"idx,relPath,artist,track,album,lastPlayed,timesPlayed";
	self.directorySearchQueue = [NSMutableArray array];
	_entryList = [[NSMutableArray alloc]init];
	_entryCache = [[NSMutableDictionary alloc]init];
	[self chooseRootDirectoryStartAt:nil];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
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

-(void)tryReplaceFilePath:(NSString*)relPath row:(NSDictionary*)restOfRow
{
	
}

-(void)tryInsertFilePath:(NSString*)filePath artist:(NSString*)artist track:(NSString*)track album:(NSString*)album
{
	NSString *relpath = [self pathRelativeToBase:filePath];
	if (artist == nil || track == nil || album == nil)
		NSLog(@"nils for %@",relpath);
	if (artist == nil)
		artist = @"";
	if (track == nil)
		track = @"";
	if (album == nil)
		album = @"";
	NSString *qs = @"select idx,artist,track,album from tracks where relPath = ? ";
	sqlite3_stmt *stmt = [self.db prepareQuery:qs withParams:@[relpath]];
	NSDictionary *row = [self.db getRow:stmt];
	[self.db closeStatement:stmt];
	if (row)
		[self tryReplaceFilePath:relpath row:row];
	else
	{
		NSString *is = @"insert into tracks(relPath,artist,track,album) values(?,?,?,?)";
		//[self.db beginTransaction];
		[self.db doQuery:is parameters:@[relpath,artist,track,album]];
		//[self.db commitTransaction];
	}
}
-(void)processFile:(NSString*)filePath
{
	NSURL *url = [NSURL fileURLWithPath:filePath];
	NSString *type = nil;
	NSError *err = nil;
	if ([url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&err])
	{
		if (UTTypeConformsTo((__bridge CFStringRef)type,(CFStringRef)@"public.audio"))
		{
			AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
			
			NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
			NSArray *titles = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
			NSArray *artists = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
			NSArray *albumNames = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
			
			//AVMetadataItem *artwork = [artworks objectAtIndex:0];
			AVMetadataItem *title = [titles firstObject];
			AVMetadataItem *artist = [artists firstObject];
			AVMetadataItem *albumName = [albumNames firstObject];
			DoOnDatabaseQueue(^{
				[self tryInsertFilePath:filePath artist:artist.value track:title.value album:albumName.value];
			});
		}
	}
}
-(void)processQueue
{
	int isrtCount = 0;
	while ([self.directorySearchQueue count] > 0)
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
}

-(void)openDB
{
	if(self.rootURL)
	{
		NSString *path = [[self.rootURL path]stringByAppendingPathComponent:@"aupl"];
		[DBSQL setupSingletonWithName:path andDBScriptName:@"tables"];
		self.db = Database();
	}
	[self.directorySearchQueue addObject:[self.rootURL path]];
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	[self processQueue];
	//});
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
	if ([c1 isEqualToString:@"artist"])
		return mcols;
	NSInteger idx= [mcols indexOfObject:c1];
	if (idx != NSNotFound)
		swapidxes(mcols, 0,idx);
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

-(void)retrieveIndices
{
	NSString *st = @"select idx from tracks order by ";
	NSString *orderString = [[self columnsOrderBy:self.sortColumn]componentsJoinedByString:@","];
	NSString *qs = [NSString stringWithFormat:@"%@%@",st,orderString];
	sqlite3_stmt *stmt = [self.db prepareQuery:qs withParams:@[]];
	NSDictionary *row = [self.db getRow:stmt];
	while (row)
	{
		[_entryList addObject:row[@"idx"]];
		row = [self.db getRow:stmt];
	}
	[self.db closeStatement:stmt];
}

-(void)refresh:(int)flags
{
	if (flags & AD_REFRESH_ALL_DATA)
		[_entryCache removeAllObjects];
	NSNumber *nrct = [self.db valueFromQuery:@"select count(*) from tracks"];
	int tablect = [nrct intValue];
	if (tablect != [_entryList count])
	{
		[_entryList removeAllObjects];
		[self retrieveIndices];
		[self.mainTableView reloadData];
	}
}

-(NSMutableDictionary*)trackForIdx:(NSInteger)idx
{
	if (_entryCache[@(idx)] == nil)
	{
		[self retrieveRowForIdx:idx];
	}
	return _entryCache[@(idx)];
}
#pragma mark
#pragma mark table stuff

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(NSInteger)rowIndex
{
	if (rowIndex < 0 || rowIndex >= [_entryList count])
		return nil;
	NSInteger idx = [_entryList[rowIndex]integerValue];
	NSDictionary *d = [self trackForIdx:idx];
	return d[[aTableColumn identifier]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (_entryList)
		return [_entryList count];
	return 0;
}

@end
