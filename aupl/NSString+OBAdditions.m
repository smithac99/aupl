//
//  NSString+StringAdditions.m
//  ACSDraw
//
//  Created by Alan on 15/07/2013.
//
//

#import "NSString+OBAdditions.h"

static NSArray *stringSplitByCharType(NSString* str)
{
    NSMutableArray *arr = [NSMutableArray array];
    if ([str length] > 0)
    {
        NSInteger idx = 1,startindex = 0;
        while (idx < [str length])
        {
            while (idx < [str length] && isnumber([str characterAtIndex:idx]) == isnumber([str characterAtIndex:idx-1]))
                idx++;
            if (idx > startindex)
                [arr addObject:[str substringWithRange:NSMakeRange(startindex, idx - startindex)]];
            startindex = idx;
            idx++;
        }
        if (startindex < [str length])
            [arr addObject:[str substringFromIndex:startindex]];
    }
    return arr;
}

static NSComparisonResult orderStringArray(NSArray *a1,NSArray *a2)
{
    for (int idx = 0;true;idx++)
    {
        if (idx >= [a1 count])
        {
            if (idx >= [a2 count])
                return NSOrderedSame;
            else
                return NSOrderedAscending;
        }
        if (idx >= [a2 count])
        {
            return NSOrderedDescending;
        }
        NSString *s1 = a1[idx],*s2 = a2[idx];
        NSComparisonResult res;
        if ([s1 isNumeric] && [s2 isNumeric])
        {
            NSInteger v1 = [s1 integerValue];
            NSInteger v2 = [s2 integerValue];
            if (v1 < v2)
                res = NSOrderedAscending;
            else if (v1 > v2)
                res = NSOrderedDescending;
            else
                res = NSOrderedSame;
        }
        else
            res = [s1 caseInsensitiveCompare:s2];
        if (res != NSOrderedSame)
            return res;
    }
}

@implementation NSString (OBAdditions)

-(BOOL)containsChar:(unichar)uc
{
    NSString *str = [NSString stringWithCharacters:&uc length:1];
    NSRange r = [self rangeOfString:str];
    return r.length > 0;
}

-(BOOL)isNumeric
{
    static NSCharacterSet *nonnum = nil;
    if (nonnum == nil)
        nonnum = [[NSCharacterSet decimalDigitCharacterSet]invertedSet];
    return ([self rangeOfCharacterFromSet:nonnum].location == NSNotFound);
}

- (NSComparisonResult)caseInsensitiveCompareWithNumbers:(NSString *)aString
{
    return orderStringArray(stringSplitByCharType(self),stringSplitByCharType(aString));
}

-(NSArray *)nonBlankComponentsSeparatedByString:(NSString *)separator
{
    NSArray *ws = [self componentsSeparatedByString:separator];
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *s in ws)
        if ([s length] > 0)
            [words addObject:s];
    return words;
}

-(NSArray *)nonBlankComponentsSeparatedByCharactersInSet:(NSCharacterSet *)separator
{
    NSArray *ws = [self componentsSeparatedByCharactersInSet:separator];
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *s in ws)
        if ([s length] > 0)
            [words addObject:s];
    return words;
}

-(NSString*)reversed
{
	if ([self length] == 0)
		return @"";
	return [[self substringFromIndex:[self length] - 1]stringByAppendingString:[[self substringToIndex:[self length]-1]reversed]];
}

-(NSArray<NSString*>*)toArray
{
    NSMutableArray *arr = [NSMutableArray array];
    for (NSInteger i = 0;i < [self length];i++)
        [arr addObject:[self substringWithRange:NSMakeRange(i, 1)]];
    return arr;
}
@end
