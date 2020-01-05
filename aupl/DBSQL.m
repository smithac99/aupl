//
//  DBSQL.m
//  Xprz0
//
//  Created by alan on 10/04/16.
//  Copyright © 2016 onebillion. All rights reserved.
//

#import "DBSQL.h"
#import "NSString+OBAdditions.h"

dispatch_queue_t dbQueue;


void DoOnDatabaseQueue(void (^block)(void))
{
    dispatch_sync(dbQueue, ^{
        block();
    });
}

void DoOnDatabase(void (^block)(DBSQL *db))
{
    dispatch_sync(dbQueue, ^{
        DBSQL *db = Database();
        block(db);
    });
}



DBSQL *dbsql;

DBSQL* Database()
{
    return dbsql;
}


BOOL IsFloat(NSNumber *n)
{
	CFNumberType numberType = CFNumberGetType((CFNumberRef)n);
	switch (numberType)
	{
		case kCFNumberFloatType:
		case kCFNumberDoubleType:
		case kCFNumberCGFloatType:
		case kCFNumberFloat32Type:
		case kCFNumberFloat64Type:
			return YES;
			break;
		default:
			break;
	}
	return NO;
}

BOOL IsLong(NSNumber *n)
{
    CFNumberType numberType = CFNumberGetType((CFNumberRef)n);
    switch (numberType)
    {
        case kCFNumberSInt64Type:
        case kCFNumberLongType:
        case kCFNumberLongLongType:
            return YES;
            break;
        default:
            break;
    }
    return NO;
}

@implementation DBSQL
{
    sqlite3 *database;
}


+(void)setupSingletonWithName:(NSString*)name andDBScriptName:(NSString*)dbScriptName
{
    dbsql = [[DBSQL alloc]initWithFileName:[NSString stringWithFormat:@"%@.sqlite",name]];
    DoOnDatabaseQueue(^{
        if (![dbsql tableExists:@"tracks"])
        {
            [dbsql runSQLFromFile:[[NSBundle mainBundle]pathForResource:dbScriptName ofType:@"ddl"]];
        }
    });
}


-(DBSQL*)initWithFileName:(NSString*)fn
{
	if ((self = [super init]))
	{
        dbQueue = dispatch_queue_create("org.onebillion.dbqueue", NULL);
		self.dbFileName = fn;
		self.dbPath = fn;
		self.tableName = nil;
		database = NULL;
        DoOnDatabaseQueue(^{
            [self openDB];
        });
	}
	return self;
}

-(void)dealloc
{
	[self closeDB];
}

#pragma mark -

-(BOOL)resetDatabase
{
    if(dbsql)
    {
        NSString *dbpath = dbsql.dbPath;
        if (dbpath)
        {
            dbsql = nil;
            NSError *err = nil;
            [[NSFileManager defaultManager]removeItemAtPath:dbpath error:&err];
            if (err)
                NSLog(@"Reset Database - %@",[err localizedDescription]);
            
            return YES;
        }
    }
    return NO;
}


-(void)openDB
{
	if (database)
		return;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (![fileManager fileExistsAtPath:self.dbPath])
	{
	}
	int err = 0;
	if ((err=sqlite3_open([self.dbPath UTF8String], &database)) != SQLITE_OK)
	{
		NSAssert1(0, @"Error: initializeDatabase: could not open database (%s)", sqlite3_errmsg(database));
	}
}

-(void)closeDB
{
	if (database)
		sqlite3_close(database);
	database = NULL;
}

-(void)beginTransaction
{
    [self doQuery:@"BEGIN TRANSACTION"];
	
}

-(void)commitTransaction
{
    [self doQuery:@"COMMIT"];
}

-(BOOL)tableExists:(NSString*)tableName
{
	if ([self valueFromQuery:@"SELECT tbl_name FROM sqlite_master WHERE type = ? AND name = ?;" withParams:@[@"table", tableName]])
	{
		return true;
	}
	else
	{
		return false;
	}
}
-(BOOL)runSQLFromFile:(NSString*)filePath
{
	NSError *err = nil;
	NSString *str = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&err];
	if (err)
	{
		NSLog(@"runSQLFromFile - %@",[err localizedDescription]);
		return NO;
	}
	NSArray *strings = [str nonBlankComponentsSeparatedByString:@"//"];
	for (NSString *s in strings)
	{
		[self doQuery:s];
	}
	return YES;
}

-(sqlite3_stmt*)createStatement:(const char*)query parameters:(NSArray*)params
{
	NSInteger param_count;
    sqlite3_stmt *statement;
	if (sqlite3_prepare_v2(database, query, -1, &statement, NULL) != SQLITE_OK)
	{
		NSLog(@"bindSQL:withArray: could not prepare statement (%s) %s", sqlite3_errmsg(database), query);
		statement = NULL;
		return statement;
	}
	
	param_count = sqlite3_bind_parameter_count(statement);
	if (param_count != [params count])
	{
		NSLog(@"bindSQL:withArray: wrong number of parameters (%s)", query);
		statement = NULL;
		return statement;
	}
	
	if (param_count)
	{
		for (int i = 0; i < param_count; i++)
		{
			id o = params[i];
			
			if ([o isEqual:[NSNull null]])
				sqlite3_bind_null(statement, i + 1);
			else if ([o isKindOfClass:[NSNumber class]])
			{
				if (IsFloat(o))
					sqlite3_bind_double(statement, i + 1, [o doubleValue]);
				else if (IsLong(o))
					sqlite3_bind_int64(statement, i + 1, [o longLongValue]);
                else
                    sqlite3_bind_int(statement, i + 1, [o intValue]);
			}
			else if ([o isKindOfClass:[NSString class]])
				sqlite3_bind_text(statement, i + 1, [o UTF8String], -1, SQLITE_TRANSIENT);
			else
			{    // unhhandled type
				NSLog(@"bindSQL:withArray: Unhandled parameter type: %@ query: %s", [o class], query);
				statement = NULL;
				return statement;
			}
		}
	}
	return statement;
}

-(NSNumber*)doQuery:(NSString*)query parameters:(NSArray*)params
{
	const char *cQuery = [query UTF8String];
	sqlite3_stmt *statement = [self createStatement:cQuery parameters:params];
	if (statement == NULL)
		return @0;
	sqlite3_step(statement);
	if(sqlite3_finalize(statement) == SQLITE_OK)
	{
		return @(sqlite3_changes(database));
	}
	else
	{
		NSLog(@"doQuery: sqlite3_finalize failed (%s) query: %s", sqlite3_errmsg(database), cQuery);
		return @0;
	}
}

-(NSNumber*)doQuery: (NSString*)query
{
	return [self doQuery:query parameters:@[]];
}

-(id)valueFromQuery:(NSString*) query withParams:(NSArray*)params
{
	const char *cQuery = [query UTF8String];
	sqlite3_stmt *statement = [self createStatement:cQuery parameters:params];
	if (statement == NULL)
		return nil;
    return [self getValue:statement];
}

-(id)valueFromQuery:(NSString*)query
{
	return [self valueFromQuery:query withParams:@[]];
}

-(sqlite3_stmt*)prepareQuery:(NSString*)query withParams:(NSArray*)params
{
	const char *cQuery = [query UTF8String];
	return [self createStatement:cQuery parameters:params];
}

-(NSDictionary*)getRow:(sqlite3_stmt*)statement
{
    @try {
        static NSMutableDictionary * dRow = nil;
        int rc = sqlite3_step(statement);
        if (rc == SQLITE_DONE)
        {
            return nil;
        }
        else  if (rc == SQLITE_ROW)
        {
            int col_count = sqlite3_column_count(statement);
            if (col_count >= 1)
            {
                dRow = [NSMutableDictionary dictionaryWithCapacity:col_count];
                for (int i = 0; i < col_count; i++)
                    dRow[ @(sqlite3_column_name(statement, i)) ] = [self columnValue:i statement:statement];
                return dRow;
            }
        }
        else
        {    // rc != SQLITE_ROW
            NSLog(@"getPreparedRow: could not get row: %s", sqlite3_errmsg(database));
            return nil;
        }
        return nil;

    } @catch (NSException *exception) {
        NSLog( @"NSException caught" );
        NSLog( @"Name: %@", exception.name);
        NSLog( @"Reason: %@", exception.reason );
    }
       return nil;
}

-(int)getRowCount:(sqlite3_stmt*)statement
{
    return sqlite3_column_int(statement, 0);
}

-(void)closeStatement:(sqlite3_stmt*)statement
{
    sqlite3_finalize(statement);
}

// returns one value from the first column of the query
-(id)getValue:(sqlite3_stmt*)statement
{
	int rc = sqlite3_step(statement);
	if (rc == SQLITE_DONE)
	{
		sqlite3_finalize(statement);
		return nil;
	}
	else if (rc == SQLITE_ROW)
	{
		int col_count = sqlite3_column_count(statement);
		if (col_count < 1)
			return nil;
        id o = [self columnValue:0 statement:statement];
		sqlite3_finalize(statement);
		return o;
	}
	else
	{
		NSLog(@"getPreparedValue: could not get row: %s", sqlite3_errmsg(database));
		return nil;
	}
}

-(id)columnValue:(int)columnIndex statement:(sqlite3_stmt*)statement
{
	id o = nil;
	switch(sqlite3_column_type(statement, columnIndex))
	{
		case SQLITE_INTEGER:
			o = @(sqlite3_column_int64(statement, columnIndex));
			break;
		case SQLITE_FLOAT:
			o = [NSNumber numberWithFloat:sqlite3_column_double(statement, columnIndex)];
			break;
		case SQLITE_TEXT:
			o = [NSString stringWithUTF8String:(char *)(const char *) sqlite3_column_text(statement, columnIndex)];
			break;
		case SQLITE_BLOB:
			o = [NSData dataWithBytes:sqlite3_column_blob(statement, columnIndex) length:sqlite3_column_bytes(statement, columnIndex)];
			break;
		case SQLITE_NULL:
			o = [NSNull null];
			break;
	}
	return o;
}

-(void)doDeleteOnTable:(NSString*)table where:(NSDictionary*)whereDict
{
    NSMutableArray *whereComponents = [NSMutableArray array];
    NSMutableArray *params = [NSMutableArray array];
    
    for(NSString *key in whereDict.allKeys)
    {
        [params  addObject:whereDict[key]];
        [whereComponents addObject:[NSString stringWithFormat:@"%@ = ?", key]];
    }
    
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"DELETE FROM %@",table]];
    if(whereComponents.count > 0)
    {
        [query appendString:[NSString stringWithFormat:@" WHERE %@",
                             [whereComponents componentsJoinedByString:@" AND "]]];
    }
    
    [self doQuery:query parameters:params];
}

-(NSNumber*)doInsertOnTable:(NSString*)table data:(NSDictionary*)dataDict
{
    NSMutableArray *params = [NSMutableArray array];
    NSMutableArray *vals = [NSMutableArray array];
    NSArray *keys = dataDict.allKeys;

    for(NSString *key in keys)
    {
        [params addObject:dataDict[key]];
        [vals addObject:@"?"];
    }
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES(%@)",table,
                       [keys componentsJoinedByString:@","],
                       [vals componentsJoinedByString:@","]];
    
    return [self doQuery:query parameters:params];
}

-(NSNumber*)doReplaceOnTable:(NSString*)table data:(NSDictionary*)dataDict
{
    NSMutableArray *params = [NSMutableArray array];
    NSMutableArray *vals = [NSMutableArray array];
    NSArray *keys = dataDict.allKeys;
    
    for(NSString *key in keys)
    {
        [params addObject:dataDict[key]];
        [vals addObject:@"?"];
    }
    
    NSString *query = [NSString stringWithFormat:@"REPLACE INTO %@(%@) VALUES(%@)",table,
                       [keys componentsJoinedByString:@","],
                       [vals componentsJoinedByString:@","]];
    
    return [self doQuery:query parameters:params];
}


-(NSNumber*)doUpdateOnTable:(NSString*)table where:(NSDictionary*)whereDict update:(NSDictionary*)updateDict
{
    NSMutableArray *updateComponents = [NSMutableArray array];
    NSMutableArray *whereComponents = [NSMutableArray array];
    NSMutableArray *params = [NSMutableArray array];
    
    for(NSString *key in updateDict.allKeys)
    {
        [params  addObject:updateDict[key]];
        [updateComponents addObject:[NSString stringWithFormat:@"%@ = ?", key]];
    }
    
    for(NSString *key in whereDict.allKeys)
    {
        [params  addObject:whereDict[key]];
        [whereComponents addObject:[NSString stringWithFormat:@"%@ = ?", key]];
    }
    NSString *query = nil;
    if(whereDict.count > 0)
    {
        query = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@",table,
                       [updateComponents componentsJoinedByString:@","],
                       [whereComponents componentsJoinedByString:@" AND "]];
    }
    else
    {
        query = [NSString stringWithFormat:@"UPDATE %@ SET %@",table,
                 [updateComponents componentsJoinedByString:@","]];
    }
    
    return [self doQuery:query parameters:params];
}

-(sqlite3_stmt*)prepareSelectOnTable:(NSString*)table columns:(NSArray*)columns where:(NSDictionary*)whereDict
{
    NSMutableArray *whereComponents = [NSMutableArray array];
    NSMutableArray *params = [NSMutableArray array];
    
    for(NSString *key in whereDict.allKeys)
    {
        [params addObject:whereDict[key]];
        [whereComponents addObject:[NSString stringWithFormat:@"%@ = ?", key]];
    }
    
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"SELECT %@ FROM %@",
                        [columns componentsJoinedByString:@","],table]];
    if(whereComponents.count > 0)
    {
        [query appendString:[NSString stringWithFormat:@" WHERE %@",
                             [whereComponents componentsJoinedByString:@" AND "]]];
    }
    
     return [self prepareQuery:query withParams:params];
}

-(sqlite3_stmt*)prepareSelectOnTable:(NSString*)table columns:(NSArray*)columns where:(NSDictionary*)whereDict orderBy:(NSArray*)orderBy
{
    NSMutableArray *whereComponents = [NSMutableArray array];
    NSMutableArray *params = [NSMutableArray array];
    
    for(NSString *key in whereDict.allKeys)
    {
        [params  addObject:whereDict[key]];
        [whereComponents addObject:[NSString stringWithFormat:@"%@ = ?", key]];
    }
    
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"SELECT %@ FROM %@",
                         [columns componentsJoinedByString:@","],table]];
    if(whereComponents.count > 0)
    {
        [query appendString:[NSString stringWithFormat:@" WHERE %@",
                             [whereComponents componentsJoinedByString:@" AND "]]];
    }
    
    [query appendString:[NSString stringWithFormat:@" ORDER BY %@",
                         [orderBy componentsJoinedByString:@","]]];
    
    return [self prepareQuery:query withParams:params];
}

-(NSNumber*)lastInsertRowId
{
    return @(sqlite3_last_insert_rowid(database));
}

@end
