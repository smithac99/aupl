//
//  AuplApplication.m
//  aupl
//
//  Created by Alan Smith on 02/07/2020.
//  Copyright © 2020 alancsmith. All rights reserved.
//

#import "AuplApplication.h"

@implementation AuplApplication

-(void)keyDown:(NSEvent *)theEvent
{
    unichar key = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
    if (key == ' ')
        NSLog(@"space");
    else
        [super keyDown:theEvent];
}

@end
