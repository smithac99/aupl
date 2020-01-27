//
//  NSMutableArray+NSMutableArray_Additions.m
//  aupl
//
//  Created by Alan Smith on 24/01/2020.
//  Copyright © 2020 alancsmith. All rights reserved.
//

#import "NSMutableArray+NSMutableArray_Additions.h"

#import <AppKit/AppKit.h>


@implementation NSMutableArray (NSMutableArray_Additions)
-(void)insertObjects:(NSArray*) arr atIndex:(NSInteger)i
{
    [arr enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self insertObject:obj atIndex:i];
    }];
}
-(void)moveObjectsAtIndexes:(NSIndexSet*)ixs toIndex:(NSInteger)index
{
    if ([ixs count] == 0)
        return;
    NSMutableArray *objs = [NSMutableArray array];
    NSInteger i = [ixs lastIndex];
    while (i >= index && i != NSNotFound)
    {
        [objs insertObject:self[i] atIndex:0];
        [self removeObjectAtIndex:i];
        i = [ixs indexLessThanIndex:i];
    }
    [self insertObjects:objs atIndex:index];
    NSMutableIndexSet *mixs = [NSMutableIndexSet indexSet];
    while (i >= 0 && i != NSNotFound)
    {
        [mixs addIndex:i];
        [self insertObject:self[i] atIndex:index];
        i = [ixs indexLessThanIndex:i];
    }
    [self removeObjectsAtIndexes:mixs];
}

@end
