//
//  BackgroundImageView.m
//  JPEGDeux
//
//  Created by Peter on Wed Sep 05 2001.

#import "BackgroundImageView.h"
#import "Procedural.h"
#import "Scaling.h"
#import <QuartzCore/QuartzCore.h>

@implementation BackgroundImageView

- (id)initWithFrame:(NSRect)frame {
    if (self=[super initWithFrame:frame]) {
        myBackgroundColor=[NSColor blackColor];
        myScaling=ScaleNone;
        myNameAttributes=[[NSDictionary alloc] initWithObjectsAndKeys:
            [NSColor whiteColor], NSForegroundColorAttributeName,
            [NSColor blackColor], NSBackgroundColorAttributeName,
            nil];

		imageView = [[NSImageView alloc] initWithFrame:self.bounds];
		imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		imageView.imageScaling = NSImageScaleProportionallyUpOrDown;

        // Enable layer-backed view for better rendering
        [imageView setWantsLayer:YES];

        // Use high-quality interpolation for upscaling
        // kCAFilterTrilinear provides smooth upscaling
        imageView.layer.magnificationFilter = kCAFilterTrilinear;
        imageView.layer.minificationFilter = kCAFilterTrilinear;

		[self addSubview:imageView];

    }
    return self;
}

// The rotation is in radians, counter-clockwise, always a multiple of 90 degrees.
- (int)quarterTurns {
    int turns=(int)lrint(myRotation / M_PI_2) % 4;
    return turns < 0 ? turns+4 : turns;
}

// Hands the image view the picture turned about its center. The turned picture is
// as wide as the original is tall (for 90 and 270 degrees), so the image view
// fits it to the window as if it had been that shape all along.
- (void)updateDisplayedImage {
    NSImage* shown=myImage;
    int turns=[self quarterTurns];
    NSSize size=[myImage size];
    if (myImage && turns && size.width > 0 && size.height > 0) {
        NSSize turnedSize=(turns & 1) ? NSMakeSize(size.height, size.width) : size;
        NSImage* source=myImage;
        shown=[NSImage imageWithSize:turnedSize flipped:NO drawingHandler:^BOOL(NSRect dst) {
            NSAffineTransform* transform=[NSAffineTransform transform];
            [transform translateXBy:NSWidth(dst)/2 yBy:NSHeight(dst)/2];
            [transform rotateByDegrees:90.0*turns];
            [transform translateXBy:-size.width/2 yBy:-size.height/2];
            [NSGraphicsContext saveGraphicsState];
            [transform concat];
            [source drawInRect:NSMakeRect(0, 0, size.width, size.height)
                      fromRect:NSZeroRect
                     operation:NSCompositingOperationSourceOver
                      fraction:1.0];
            [NSGraphicsContext restoreGraphicsState];
            return YES;
        }];
    }
    [imageView setImage:shown];
}

- (void)setRotation:(float)r {
    myRotation=r;
    [self updateDisplayedImage];
}

- (void)flipHorizontal {
    myHFlipped=!myHFlipped;
}

- (void)flipVertical {
    myVFlipped=!myVFlipped;
}

- (void)setImageName:(NSString*)name {
    myImageName=[name copy];
	
}

- (NSSize)scaledSizeForSize:(NSSize)size {
    // Rotation is not considered here: this pre-sizes the next image before it is
    // shown, and the image view re-fits whatever turn the picture ends up with.
    NSSize mySize=[self bounds].size;
    switch (myScaling) {
        case ScaleDownToFit:
            if (size.height < mySize.height && size.width < mySize.width) return size;
            //note fall through
        case ScaleToFit: return mySize;

        case ScaleNone: return size;

        case ScaleDownProportionally:
            if (size.height < mySize.height && size.width < mySize.width) return size;
            //note fall through
        case ScaleProportionally:
            if (size.height*mySize.width > size.width * mySize.height) {
                //image is too tall
                size.width*=mySize.height/size.height;
                size.height=mySize.height;
            }
            else {
                //image is too wide
                size.height*=mySize.width/size.width;
                size.width=mySize.width;
            }
            //note fall through
        default: //this should shut gcc up
            return size;
    }
}


- (void)drawImageName:(NSRect)rect {
    if (myImageName) {
        NSSize size=[myImageName sizeWithAttributes:NULL];
		
		NSRect imageLabelRect = NSMakeRect(0, 0, NSMaxX(rect), size.height);
		
		if (myImageLabel) {
			[myImageLabel removeFromSuperview];
		}
		
		myImageLabel = [[NSTextField alloc] initWithFrame:imageLabelRect];
		[myImageLabel setStringValue:myImageName];
		[myImageLabel setBezeled:NO];
		[myImageLabel setDrawsBackground:NO];
		[myImageLabel setEditable:NO];
		[myImageLabel setSelectable:NO];
		[myImageLabel setTextColor:[NSColor whiteColor]];
		
		[self addSubview:myImageLabel];

    }
}

- (void)setColor:(NSColor*)color {
    myBackgroundColor=color;
    myNameAttributes=[[NSDictionary alloc] initWithObjectsAndKeys:
        [NSColor whiteColor], NSForegroundColorAttributeName,
        myBackgroundColor, NSBackgroundColorAttributeName,
        nil];
}

- (NSColor*)getColor {
    return myBackgroundColor;
}

- (void)drawRect:(NSRect)rect {
	[super drawRect:rect];
	
	if (myImageName) {
		[self drawImageName:rect];
	}
}

- (void)setImage:(NSImage*)image {
    // Stop any playing video first
    [self stopVideo];

    myImage=image;
    isShowingVideo = NO;

    // Show image view, hide video view
    [imageView setHidden:NO];
    [videoPlayerView setHidden:YES];

    [self updateDisplayedImage];

    [self display];
}

- (NSImage*)image {
    return myImage;
}

#pragma mark - Video Support

- (void)setupVideoPlayerIfNeeded {
    if (!videoPlayerView) {
        videoPlayerView = [[AVPlayerView alloc] initWithFrame:self.bounds];
        videoPlayerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        videoPlayerView.controlsStyle = AVPlayerViewControlsStyleInline;
        videoPlayerView.videoGravity = AVLayerVideoGravityResizeAspect;
        videoPlayerView.showsFullScreenToggleButton = YES;
        [videoPlayerView setWantsLayer:YES];
        [self addSubview:videoPlayerView];
        [videoPlayerView setHidden:YES];
    }
}

- (void)setVideoURL:(NSURL*)url {
    if (!url) return;

    [self setupVideoPlayerIfNeeded];

    // Stop current video if any
    [self stopVideo];

    // Create player item and player
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:url];

    videoPlayer = [AVPlayer playerWithPlayerItem:playerItem];
    videoPlayerView.player = videoPlayer;

    // Hide image view, show video view
    [imageView setHidden:YES];
    [videoPlayerView setHidden:NO];
    isShowingVideo = YES;

    // Start playing
    [videoPlayer play];

    // Loop video when it ends
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(videoDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];

    [self display];
}

- (void)videoDidEnd:(NSNotification *)notification {
    // Loop the video
    AVPlayerItem *item = notification.object;
    [item seekToTime:kCMTimeZero completionHandler:nil];
    [videoPlayer play];
}

- (void)stopVideo {
    if (videoPlayer) {
        [videoPlayer pause];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:videoPlayer.currentItem];
        videoPlayer = nil;
        videoPlayerView.player = nil;
    }
    isShowingVideo = NO;
}

- (BOOL)isPlayingVideo {
    return isShowingVideo && videoPlayer != nil;
}

- (void)setImageScaling:(BetterImageScaling)scaling {
    myScaling=scaling;

    // Map BetterImageScaling to NSImageScaling for the imageView
    switch (scaling) {
        case ScaleProportionally:
            imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
            break;
        case ScaleToFit:
            imageView.imageScaling = NSImageScaleAxesIndependently;
            break;
        case ScaleNone:
            imageView.imageScaling = NSImageScaleNone;
            break;
        case ScaleDownProportionally:
        case ScaleDownToFit:
            imageView.imageScaling = NSImageScaleProportionallyDown;
            break;
        default:
            imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
            break;
    }
}

- (BetterImageScaling)imageScaling {
    return myScaling;
}

@end
