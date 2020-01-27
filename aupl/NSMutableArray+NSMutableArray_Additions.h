//
//  NSMutableArray+NSMutableArray_Additions.h
//  aupl
//
//  Created by Alan Smith on 24/01/2020.
//  Copyright © 2020 alancsmith. All rights reserved.
//

#import <AppKit/AppKit.h>


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableArray (NSMutableArray_Additions)

-(void)moveObjectsAtIndexes:(NSIndexSet*)ixs toIndex:(NSInteger)index;
-(void)insertObjects:(NSArray*) arr atIndex:(NSInteger)idx;

@end

NS_ASSUME_NONNULL_END
