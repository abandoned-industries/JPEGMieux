//
//  ScreenShow.h
//  JPEGDeux
//
//  Created by Peter on Wed Sep 05 2001.
//

@class BackgroundImageView;

#import "SlideShow.h"
#import "ScreenShow.h"
#import <QuartzCore/QuartzCore.h>

@interface TransitionScreenShow : ScreenShow <CAAnimationDelegate> {
    NSWindow* myOtherCoveringWindow;
    BackgroundImageView* myOtherImageView;
    SEL myTransition;
    float myIncrement;
	NSTimeInterval transitionSpeed;
}

//transitions
- (void)fade:(NSImage*)image;
- (void)scrollFromBottom:(NSImage*)image;
- (void)scrollFromTop:(NSImage*)image;
- (void)scrollFromRight:(NSImage*)image;
- (void)scrollFromLeft:(NSImage*)image;

@end
