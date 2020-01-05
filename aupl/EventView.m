//
//  EventView.m
//  aupl
//
//  Created by Alan Smith on 04/01/2020.
//  Copyright © 2020 alancsmith. All rights reserved.
//

#import "EventView.h"

@implementation EventView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [[NSColor colorWithRed:0.9 green:0.9 blue:0.92 alpha:1]set];
    NSRectFill(dirtyRect);

}

@end
