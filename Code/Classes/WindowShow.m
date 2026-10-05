//
//  WindowShow.m
//  JPEGDeux
//
//  Created by Peter on Tue Sep 04 2001.
//

#import "WindowShow.h"
#import "BackgroundImageView.h"

@implementation WindowShow

- (void)beginShow:(NSArray*)files {
    myWindow=[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                               styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskClosable
                               backing:NSBackingStoreBuffered
                               defer:NO];
    myImageView=[[BackgroundImageView alloc] initWithFrame:NSMakeRect(0, 0, 600, 350)];
    [myImageView setFrame:[myWindow frame]];
    [myImageView setImageScaling:myScaling];
    [myWindow setContentView:myImageView];
    [myWindow setReleasedWhenClosed:NO];
    [myWindow setDelegate:self];
    
    [myWindow center];
    [myWindow setFrameUsingName:@"WindowShowFrame"];
    [myWindow setFrameAutosaveName:@"WIndowShowFrame"];
    [myWindow makeKeyAndOrderFront:self];
    [super beginShow:files];
}

- (void)setImage:(NSImage*)image {
    [myImageView setRotation:myRotation];
    [myImageView setImage:image];
}

- (void)setVideoURL:(NSURL*)url {
    [myImageView setVideoURL:url];
}

- (void)setImageName:(NSString*)name {
    [myImageView setImageName:name];
}

- (void)loadNextImage {
    [super loadNextImage];
    //cached images are already set to the proper size
    if (myNextImage && myCachedImages==nil) {
        NSSize oldSize=[myNextImage size];
        NSSize newSize=[myImageView scaledSizeForSize:oldSize];
        if (! NSEqualSizes(newSize, oldSize)) {
            [myNextImage setSize:newSize];
            // Note: removed lockFocus/unlockFocus - unnecessary and blocks on large images
        }
    }
}

+ (int)tagNumber {
    return 0;
}

- (void)flipHorizontal {
    [myImageView flipHorizontal];
}

- (void)flipVertical {
    [myImageView flipVertical];
}

- (void)redisplay {
    [myImageView display];
}

- (void)rotate:(int)v {
    [super rotate:v];
    [myImageView setRotation:myRotation];
}

- (BOOL)windowShouldClose:(NSWindow*)window {
    NSEvent* event=[NSEvent otherEventWithType:NSEventTypeApplicationDefined
                            location:NSMakePoint(0,0)
                            modifierFlags:0
                            timestamp:0
                            windowNumber:[window windowNumber]
                            context:nil
                            subtype:StopSlideshowEventType
                            data1:0
                            data2:0];
    [[NSApplication sharedApplication] postEvent:event atStart:YES];
    return YES;
}

- (NSSize)displaySizeForSize:(NSSize)size {
    return [myImageView scaledSizeForSize:size];
}

- (void)setBackgroundColor:(NSColor*)color {
    [myImageView setColor:color];
    [myWindow setBackgroundColor:color];
}

- (long)estimatedSizeOfCachedImages {
    // Modern Macs use 32-bit color (4 bytes per pixel)
    long bytesPerPixel = 4;
    NSSize windowSize=[myImageView bounds].size;
    return bytesPerPixel*windowSize.width*windowSize.height*[myChosenFiles count];
}

- (void)endShow {
    // Stop any playing video
    [myImageView stopVideo];

    // Close the slideshow window
    [myWindow orderOut:self];
    myWindow = nil;
    myImageView = nil;

    // Call parent cleanup
    [super endShow];
}

@end
