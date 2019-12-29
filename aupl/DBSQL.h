//
//  DBSQL.h
//  Xprz0
//
//  Created by alan on 10/04/16.
//  Copyright © 2016 onebillion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>


@interface DBSQL : NSObject

void DoOnDatabaseQueue(void (^block)(void));
void DoOnDatabase(void (^block)(DBSQL *db));

DBSQL* Database(void);

@property (nonatomic, retain) NSString *dbFileName;
@property (nonatomic, retain) NSString *dbPath;
@property (nonatomic, retain) NSString *tableName;

+(void)setupSingletonWithName:(NSString*)name andDBScriptName:(NSString*)dbScriptName;

-(DBSQL*)initWithFileName:(NSString*)fn;

-(BOOL)resetDatabase;
-(void)openDB;
-(void)closeDB;
-(void)beginTransaction;
-(void)commitTransaction;
-(BOOL)runSQLFromFile:(NSString*)filePath;
-(NSNumber*)doQuery:(NSString*)query parameters:(NSArray*)params;
-(NSNumber*)doQuery:(NSString*)query;
-(NSNumber*)doInsertOnTable:(NSString*)table data:(NSDictionary*)dataDict;
-(void)doDeleteOnTable:(NSString*)table where:(NSDictionary*)whereDict;
-(NSNumber*)doReplaceOnTable:(NSString*)table data:(NSDictionary*)dataDict;
-(NSNumber*)doUpdateOnTable:(NSString*)table where:(NSDictionary*)whereDict update:(NSDictionary*)updateDict;
-(sqlite3_stmt*)prepareSelectOnTable:(NSString*)table columns:(NSArray*)columns where:(NSDictionary*)whereDict;
-(sqlite3_stmt*)prepareSelectOnTable:(NSString*)table columns:(NSArray*)columns where:(NSDictionary*)whereDict orderBy:(NSArray*)orderBy;
-(sqlite3_stmt*)prepareQuery:(NSString*)query withParams:(NSArray*)params;
-(NSDictionary*)getRow:(sqlite3_stmt*)statement;
-(BOOL)tableExists:(NSString*)tableName;
-(NSNumber*)lastInsertRowId;
-(void)closeStatement:(sqlite3_stmt*)statement;
-(id)valueFromQuery:(NSString*)query;

@end
