//
//  EventView.m
//  aupl
//
//  Created by Alan Smith on 04/01/2020.
//  Copyright © 2020 alancsmith. All rights reserved.
//

#import "EventView.h"

@implementation EventView

-(void)awakeFromNib
{
	[super awakeFromNib];
	[controlView setHidden:YES];
	[self addTrackingArea:[[NSTrackingArea alloc]initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil]];
}
- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [[NSColor colorWithRed:0.9 green:0.9 blue:0.92 alpha:1]set];
    NSRectFill(dirtyRect);

}

-(void)mouseEntered:(NSEvent *)event
{
	[controlView setHidden:NO];
}
-(void)mouseExited:(NSEvent *)event
{
	[controlView setHidden:YES];
}
@end
