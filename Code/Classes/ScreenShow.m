//
//  ScreenShow.m
//  JPEGDeux
//
//  Created by Peter on Wed Sep 05 2001.
//

#import "ScreenShow.h"
#import "BackgroundImageView.h"
#import "TransitionScreenShow.h"

@implementation ScreenShow

- (id)initWithParams:(NSDictionary*)params {
    if ([[params objectForKey:@"Transition"] intValue] && [self class]==[ScreenShow class]) {
        return [[TransitionScreenShow alloc] initWithParams:params];
    }
    return [super initWithParams:params];
}

- (void)dealloc {
    [NSMenu setMenuBarVisible:YES];

    [myCoveringWindow orderOut:self];
}

- (void)beginShow:(NSArray*)files {
    myCoveringWindow=[[NSWindow alloc] initWithContentRect:[[NSScreen mainScreen] frame]
                       styleMask:NSWindowStyleMaskBorderless
                       backing:NSBackingStoreBuffered
                       defer:NO];
    myImageView=[[BackgroundImageView alloc] initWithFrame:[myCoveringWindow frame]];
    //myImageView=[[TransitionImageView alloc] initWithFrame:[myCoveringWindow frame]];
    [myImageView setColor:[NSColor blackColor]];
    [myImageView setImageScaling:myScaling];
    [myCoveringWindow setContentView:myImageView];

    [NSMenu setMenuBarVisible:NO];
    
    [myCoveringWindow makeKeyAndOrderFront:self];
    [super beginShow:files];
}

- (void)loadNextImage {
    [super loadNextImage];
    //cached images are already set to the proper size
    if (myNextImage && myCachedImages==nil) {
        NSSize oldSize=[myNextImage size];
        NSSize newSize=[myImageView scaledSizeForSize:oldSize];
        if (! NSEqualSizes(newSize, oldSize)) {
            [myNextImage setSize:newSize];
        }
    }
}

- (void)setImage:(NSImage*)image {
    [myImageView setRotation:myRotation];
    //myRotation=0;
    [myImageView setImage:image];
}

- (void)setVideoURL:(NSURL*)url {
    [myImageView setRotation:myRotation];
    [myImageView setVideoURL:url];
}

- (void)setImageName:(NSString*)name {
    [myImageView setImageName:name];
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

+ (int)tagNumber {
    return 1;
}

- (NSSize)displaySizeForSize:(NSSize)size {
    return [myImageView scaledSizeForSize:size];
}

- (void)setBackgroundColor:(NSColor*)color {
    [myCoveringWindow setBackgroundColor:color];
    [myImageView setColor:color];
}

- (long)estimatedSizeOfCachedImages {
    // Modern Macs use 32-bit color (4 bytes per pixel)
    long bytesPerPixel = 4;
    NSSize screenSize=[[NSScreen mainScreen] frame].size;
    return bytesPerPixel*screenSize.width*screenSize.height*[myChosenFiles count];
}

- (void)endShow {
    // Stop any playing video
    [myImageView stopVideo];

    // Restore menu bar visibility
    [NSMenu setMenuBarVisible:YES];

    // Close the fullscreen window
    [myCoveringWindow orderOut:self];
    myCoveringWindow = nil;
    myImageView = nil;

    // Call parent cleanup
    [super endShow];
}

@end
