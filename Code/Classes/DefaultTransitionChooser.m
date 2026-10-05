//
//  DefaultTransitionChooser.m
//  JPEGDeux 2
//
//  Created by Peter Ammon on Mon Nov 25 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "DefaultTransitionChooser.h"
#import "ScreenShowTransitionChooser.h"

static NSMutableDictionary* sTransitionViews;

@implementation DefaultTransitionChooser

+ (Class)classForShowTypeByTag:(int)tag {
    switch(tag) {
        case 1: return [ScreenShowTransitionChooser class];
        default: return [DefaultTransitionChooser class];
    }
}

+ (NSString*)nibName {
    return @"DefaultTransitionView";
}

+ (id)loadView {
    id result;
    if (! sTransitionViews) sTransitionViews=[[NSMutableDictionary alloc] init];
    result=[sTransitionViews objectForKey:[self nibName]];
    if (! result) {
        result=[[self alloc] init];
        NSArray *topLevelObjects = nil;
        if (! [[NSBundle mainBundle] loadNibNamed:[self nibName] owner:result topLevelObjects:&topLevelObjects]) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Nib error";
            alert.informativeText = [NSString stringWithFormat:@"JPEGMieux couldn't load %@.nib", [self nibName]];
            [alert addButtonWithTitle:@"D'oh!"];
            [alert runModal];
            result=nil;
        } else {
            [sTransitionViews setObject:result forKey:[self nibName]];
        }
    }
    return result;
}

- (NSDictionary*)valueDictionary {
    return [NSDictionary dictionary];
}

- (NSView*)view {
    return myView;
}

- (void)setValuesFromDictionary:(NSDictionary*)dict {
    
}

@end
