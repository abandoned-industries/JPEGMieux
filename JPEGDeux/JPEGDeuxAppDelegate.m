//
//  JPEGTroisAppDelegate.m
//  JPEGTrois
//
//  Created by Terrence Curran on 11/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "JPEGDeuxAppDelegate.h"

@implementation JPEGDeuxAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (IBAction)orderFrontStandardAboutPanel:(id)sender
{
    // Custom About box with build information
    NSString *buildDate = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JDBuildDate"];
    NSString *buildCommit = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JDBuildCommit"];

    NSMutableDictionary *options = [NSMutableDictionary dictionary];

    if (buildDate && buildCommit) {
        options[NSAboutPanelOptionVersion] = [NSString stringWithFormat:@"Built %@ · %@", buildDate, buildCommit];
    }

    [[NSApplication sharedApplication] orderFrontStandardAboutPanelWithOptions:options];
}

@end
