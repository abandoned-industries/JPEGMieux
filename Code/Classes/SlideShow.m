//
//  SlideShow.m
//  JPEGDeux
//
//  Created by Peter on Tue Sep 04 2001.
//

#import "SlideShow.h"
#import "MutableArrayCategory.h"
#import "MyWindowController.h"
#import "CommentFinder.h"
#import "WindowMovingTextField.h"
#import "ImageLoader.h"
#import "MediaUtils.h"
#import <AVFoundation/AVFoundation.h>
#include <errno.h>

@implementation SlideShow

- (id)initWithParams:(NSDictionary*)params {
    return [self init];
}

- (void)beginShow:(NSArray*)files {
    const unsigned int styleMask=NSWindowStyleMaskBorderless;
    myChosenFiles=[files mutableCopy];
    myOriginalFiles=[files copy];
    mySkippedFiles=[[NSMutableSet alloc] init];
    myWasShuffled=NO;
    if (myCommentStyle==CommentStyleWindow) {
        myCommentWindow=[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 6, 6)
                                                    styleMask:styleMask
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
        [myCommentWindow setLevel:NSFloatingWindowLevel];
        myCommentField=[[WindowMovingTextField alloc] initWithFrame:NSMakeRect(0, 0, 6, 6)];
        [myCommentField setEditable:NO];
        [myCommentField setSelectable:NO];
        [myCommentWindow setContentView:myCommentField];
        [myCommentWindow setMovableByWindowBackground:YES];
        [myCommentWindow setFrameUsingName:@"CommentWindow"];
        [myCommentWindow setFrameAutosaveName:@"CommentWindow"];
    }
}

- (void)toggleCommentWindow {
    myDontShowComment=!myDontShowComment;
    if (myDontShowComment) [myCommentWindow orderOut:self];
    else [myCommentWindow orderFront:self];
}

- (void)updateWindowComments {
    if (! myFileComments) [myCommentWindow orderOut:self];
    else {
//        NSSize size;
        [myCommentField setStringValue:myFileComments];
        [myCommentField sizeToFit];
        
        //size=[comment sizeWithAttributes:[NSDictionary dictionary]];
        //size.width+=30.0f;
        //size.height+=15.0f;
        [myCommentWindow setContentSize:[myCommentField bounds].size];
        if (!myDontShowComment) [myCommentWindow orderFront:self];
        //[myCommentField display];
    }
}

- (void)setImage:(NSImage*)image {
    NSLog(@"Error: superclass's setImage: called!");
}

- (NSSize)displaySizeForSize:(NSSize)size {
    NSLog(@"Error: superclass's displaySizeForSize: called!");
    return size;
}

- (void)setImageName:(NSString*)name {
    //we don't emit an error here because we don't require that subclasses implement me
}

- (void)setFileNameDisplayType:(FileNameDisplay)displayType {
    myFileNameDisplay=displayType;
}

//returns NO if we're all done, YES if we're still going
//records the time that the image is actually displayed in timeOfDisplay
- (BOOL)advanceImage:(CFTimeInterval*)timeOfDisplay {
    // Check if we have content to display (either image or video)
    if (myNextImage==nil && !myNextIsVideo) {
        return NO;
    }

    // Reset rotation when advancing to next image
    myRotation = 0;

    if (myFileNameDisplay==FileNameDisplayPath) {
		[self setImageName:[myChosenFiles objectAtIndex:myCurrentImageIndex]];
	} else if (myFileNameDisplay==FileNameDisplayName) {
		[self setImageName:[[myChosenFiles objectAtIndex:myCurrentImageIndex] lastPathComponent]];
	}

    // Display either video or image
    if (myNextIsVideo && myNextVideoURL) {
        [self setVideoURL:myNextVideoURL];
    } else {
        [self setImage:myNextImage];
    }

    if (myCommentStyle==CommentStyleWindow) [self updateWindowComments];
    *timeOfDisplay=CFAbsoluteTimeGetCurrent();
    if (++myCurrentImageIndex >= [myChosenFiles count]) return NO;
    [self loadNextImage];
    return YES;
}

- (void)setVideoURL:(NSURL*)url {
    // Subclasses should override to handle video playback
    NSLog(@"Warning: setVideoURL: called on base SlideShow class");
}

- (void)loadNextImage {
    myFileComments=nil;
    myNextIsVideo = NO;
    myNextVideoURL = nil;

    // If using smart cache, try to get from cache first (only for images)
    if (myUseSmartCache && myImageCache) {
        NSImage *cachedImage = [self cachedImageAtIndex:myCurrentImageIndex];
        if (cachedImage) {
            myNextImage = cachedImage;
            if (myCommentStyle) {
                NSString* path = [myChosenFiles objectAtIndex:myCurrentImageIndex];
                myFileComments = [commentsForJPEGFile(path) componentsJoinedByString:@"\n"];
                if (![myFileComments length]) myFileComments = nil;
            }
            // Trigger preloading of nearby images
            [self preloadNearbyImages];
            return;
        }
    }

    if (myCachedImages==nil) {
        const NSSize zeroSize={0,0};
        do {
            NSString* path=[myChosenFiles objectAtIndex:myCurrentImageIndex];

            // Check if this is a video file
            if ([MediaUtils isVideoFile:path]) {
                NSURL *videoURL = [NSURL fileURLWithPath:path];

                // Skip videos that can't be played. The file stays known to the
                // file list (as grayed out) but leaves the show, so it is
                // skipped once. The check is cached and shared with the list.
                if (![MediaUtils isVideoPlayableCached:path]) {
                    [mySkippedFiles addObject:path];
                    [myImageCache removeAllObjects];  // keyed by index, now stale
                    [myChosenFiles removeObjectAtIndex:myCurrentImageIndex--];
                    continue;
                }

                myNextIsVideo = YES;
                myNextVideoURL = videoURL;
                myNextImage = nil;
                return;
            }

            // Handle images
            myNextIsVideo = NO;
            myNextVideoURL = nil;

            if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
                NSURL* url=[NSURL URLWithString:path];
                if (url) {
					myNextImage=[[NSImage alloc] initWithContentsOfURL:url];
				} else {
					myNextImage=nil;
				}
            } else {
                // Use ImageLoader for more efficient local file loading
				myNextImage=[ImageLoader imageForPath:path];
			}
            if (myNextImage==nil) {
                [myChosenFiles removeObjectAtIndex:myCurrentImageIndex--];
                continue;
            }
            if (NSEqualSizes([myNextImage size], zeroSize)) {
                [myChosenFiles removeObjectAtIndex:myCurrentImageIndex--];
                continue;
            }
            if (myCommentStyle) {
                myFileComments=[commentsForJPEGFile(path) componentsJoinedByString:@"\n"];
                if (! [myFileComments length]) myFileComments=nil;
            }

            // Store in smart cache and trigger preloading
            if (myUseSmartCache && myImageCache) {
                [myImageCache setObject:myNextImage forKey:@(myCurrentImageIndex)];
                [self preloadNearbyImages];
            }
            return;
        } while (++myCurrentImageIndex < [myChosenFiles count]);
        myNextImage=nil;
    }
    else {
        myNextImage=[myCachedImages objectAtIndex:myCurrentImageIndex];
        if (myCommentStyle) {
            myFileComments=[myCachedImageComments objectAtIndex:myCurrentImageIndex];
            if (myFileComments==(id)[NSNull null]) myFileComments=nil;
        }
    }
}

- (NSString*)currentPath {
    return [myChosenFiles objectAtIndex:myCurrentImageIndex-1];
}

- (BOOL)removeCurrentFile:(BOOL*)wasLast {
    NSInteger cur=myCurrentImageIndex-1;
    if (cur < 0 || cur >= (NSInteger)[myChosenFiles count]) {
        if (wasLast) *wasLast=NO;
        return [myChosenFiles count] > 0;
    }
    [myChosenFiles removeObjectAtIndex:cur];
    if (myCachedImages && cur < (NSInteger)[myCachedImages count]) [myCachedImages removeObjectAtIndex:cur];
    if (myCachedImageComments && cur < (NSInteger)[myCachedImageComments count]) [myCachedImageComments removeObjectAtIndex:cur];
    [myImageCache removeAllObjects]; // keyed by index, so every entry after cur is now stale
    myCurrentImageIndex=(int)cur;    // the file that followed has slid into the slot just freed
    BOOL last=(cur >= (NSInteger)[myChosenFiles count]);
    if (wasLast) *wasLast=last;
    if (![myChosenFiles count]) return NO;
    if (!last) [self loadNextImage];
    return YES;
}

- (void)rewind:(int)count {
    int newImageIndex = 0;

    if (count != -1 && myCurrentImageIndex-count > 0) {
        newImageIndex = myCurrentImageIndex-count;
    }
    
    myCurrentImageIndex = newImageIndex;

    [self loadNextImage];
}

- (void)redisplay {
    //what should we do here?  Hopefully this won't get called
}

- (void)flipHorizontal {

}

- (void)flipVertical {

}

- (void)reshuffle {
    myWasShuffled=YES;
    [myChosenFiles shuffle];
    if (myCachedImages) {
        [myCachedImages shuffle];
    }
    if (myCachedImageComments) {
        [myCachedImageComments shuffle];
    }
    [self loadNextImage];
}

+ (int)tagNumber {
    NSLog(@"SlideShow's tag number called");
    return 0;
}

- (void)setCommentStyle:(CommentStyle)style {
    myCommentStyle=style;
}

- (void)setImageScaling:(BetterImageScaling)scaling {
    myScaling=scaling;
}

- (BetterImageScaling)imageScaling {
    return myScaling;
}

- (void)rotate:(int)v {
    myRotation = (myRotation + v*M_PI_2);
    if (myRotation >= 2*M_PI) myRotation-=2*M_PI;
}


- (void)cacheImageAtProperSize:(NSImage*)image {
    NSSize oldSize=[image size];
    NSSize newSize=[self displaySizeForSize:oldSize];
    [image setSize:newSize];
}

- (void)preload {
    NSApplication* app=[NSApplication sharedApplication];
    NSMutableArray* arr=[NSMutableArray array];
    NSMutableArray* comments;
    long i, max=[myChosenFiles count];
    const NSSize zeroSize={0,0};

    NSWindowController* controller;
    NSProgressIndicator* progress=nil;
    NSWindow* progressWindow;
    NSModalSession session;

    long estimatedBytes = [self estimatedSizeOfCachedImages];
    float estimatedMB=estimatedBytes/(float)(1<<20);

    if (estimatedMB >= WARNING_LEVEL) {
        NSString *warningMessage = [NSString stringWithFormat: @"JPEGMieux estimates that precacheing your %ld image%s "
                                    @"might take up to %.1f megabytes of RAM. "
                                    @"Are you sure you wish to continue?", max, max==1 ? "" : "s", estimatedMB];

        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Huge Precacheing!"];
        [alert setInformativeText:warningMessage];
        [alert addButtonWithTitle:@"Continue"];
        [alert addButtonWithTitle:@"Cancel"];

        NSArray *buttons = [alert buttons];
        // note: rightmost button is index 0
        [[buttons objectAtIndex:0] setKeyEquivalent: @"c"];
        [[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
        
        NSModalResponse result = [alert runModal];

        switch (result) {
            case NSAlertFirstButtonReturn:
                break;
            case NSAlertSecondButtonReturn:
                [NSException raise:CancelShowException format:@"Stop precacheing"];
                break;
            default:
                break;
        }
    }

    controller=[[MyWindowController alloc] initWithWindowNibName:@"Preload"];
    progressWindow=[controller window];
    {
        NSArray* subviews=[[progressWindow contentView] subviews];
        long i, max=[subviews count];
        for (i=0; i<max; i++) {
            if ([[subviews objectAtIndex:i] isKindOfClass:[NSProgressIndicator class]]) {
                progress=[subviews objectAtIndex:i];
                break;
            }
        }
    }
    NSAssert(progress!=nil, @"Couldn't find progress indicator in Preload window");
    [progress setMinValue:0];
    [progress setMaxValue:max];
    [progressWindow center];
    [progressWindow makeKeyAndOrderFront:self];
    NS_DURING
    session=[app beginModalSessionForWindow:progressWindow];
    if (myCommentStyle) comments=[NSMutableArray array];
    for (i=0; i<max; i++) {
        NSImage* image=nil;
        NSString* path=[myChosenFiles objectAtIndex:i];
        [app runModalSession:session];
        if ([path hasPrefix:@"http://"]) {
            NSURL* url=[NSURL URLWithString:path];
            if (url) image=[[NSImage alloc] initWithContentsOfURL:url];
        }
        else image=[[NSImage alloc] initWithContentsOfFile:path];
        if (! image || NSEqualSizes([image size], zeroSize)) {
            [myChosenFiles removeObjectAtIndex:i--];
            max--;
            [progress setMaxValue:max];
        }
        else {
            if (myCommentStyle) {
                NSArray* commentStrings=commentsForJPEGFile(path);
                NSString* commentString=[commentStrings componentsJoinedByString:@"\n"];
                if ([commentString length]) [comments addObject:commentString];
                else [comments addObject:[NSNull null]];
            }
            [self cacheImageAtProperSize:image];
            [arr addObject:image];
            [progress incrementBy:1.0];
        }
    }
    if (![arr count]) {
        // No files to cache
    }
    myCachedImages=[[NSMutableArray alloc] initWithArray:arr];
    if (myCommentStyle) myCachedImageComments=[[NSMutableArray alloc] initWithArray:comments];
    [app endModalSession:session];
    NS_HANDLER
        if (! [[localException name] isEqualToString:NSAbortModalException]) [localException raise];
        else {
            [progressWindow orderOut:self];
            [NSException raise:CancelShowException format:@"Stop precacheing"];
        }
    NS_ENDHANDLER
    [progressWindow orderOut:self];
}

- (void)setBackgroundColor:(NSColor*)color {

}

- (void)endShow {
    // Base implementation - clean up comment window if exists
    if (myCommentWindow) {
        [myCommentWindow orderOut:self];
        myCommentWindow = nil;
    }
    // Clear cache
    if (myImageCache) {
        [myImageCache removeAllObjects];
    }
}

- (long)estimatedSizeOfCachedImages {
    return 0;
}

#pragma mark - Smart Caching

- (void)enableSmartCache {
    myUseSmartCache = YES;
    if (!myImageCache) {
        myImageCache = [[NSCache alloc] init];
        // Keep a reasonable number of images in cache
        [myImageCache setCountLimit:PRELOAD_AHEAD + PRELOAD_BEHIND + 2];
    }
}

- (void)preloadNearbyImages {
    if (!myUseSmartCache || !myChosenFiles || [myChosenFiles count] == 0) {
        return;
    }

    NSInteger currentIndex = myCurrentImageIndex;
    NSInteger totalFiles = [myChosenFiles count];

    // Preload images ahead
    for (NSInteger i = 1; i <= PRELOAD_AHEAD; i++) {
        NSInteger indexToLoad = currentIndex + i;
        if (indexToLoad < totalFiles) {
            NSString *path = [myChosenFiles objectAtIndex:indexToLoad];
            NSNumber *key = @(indexToLoad);

            // Skip if already cached
            if ([myImageCache objectForKey:key]) {
                continue;
            }

            // Load asynchronously
            [ImageLoader imageForPath:path completion:^(NSImage *image) {
                if (image) {
                    [self->myImageCache setObject:image forKey:key];
                }
            }];
        }
    }

    // Preload images behind (for going back)
    for (NSInteger i = 1; i <= PRELOAD_BEHIND; i++) {
        NSInteger indexToLoad = currentIndex - i;
        if (indexToLoad >= 0) {
            NSString *path = [myChosenFiles objectAtIndex:indexToLoad];
            NSNumber *key = @(indexToLoad);

            // Skip if already cached
            if ([myImageCache objectForKey:key]) {
                continue;
            }

            // Load asynchronously
            [ImageLoader imageForPath:path completion:^(NSImage *image) {
                if (image) {
                    [self->myImageCache setObject:image forKey:key];
                }
            }];
        }
    }
}

- (NSImage *)cachedImageAtIndex:(NSInteger)index {
    if (!myUseSmartCache || !myImageCache) {
        return nil;
    }
    return [myImageCache objectForKey:@(index)];
}

#pragma mark - File List Navigation

- (NSArray *)fileList {
    return [myChosenFiles copy];
}

- (NSArray *)fileListIncludingSkipped {
    if (![mySkippedFiles count]) return [myChosenFiles copy];
    if (myWasShuffled) {
        // The original order no longer means anything; list the skipped files last
        return [[myChosenFiles copy] arrayByAddingObjectsFromArray:[mySkippedFiles allObjects]];
    }
    // Walk the original order, keeping what is still in the show (trashed files
    // dropped out of it) plus what the show skipped as unplayable
    NSSet *chosen=[NSSet setWithArray:myChosenFiles];
    NSMutableArray *merged=[NSMutableArray arrayWithCapacity:[myChosenFiles count]+[mySkippedFiles count]];
    for (NSString *path in myOriginalFiles) {
        if ([chosen containsObject:path] || [mySkippedFiles containsObject:path]) [merged addObject:path];
    }
    return merged;
}

- (NSInteger)currentFileIndex {
    // myCurrentImageIndex points to the *next* image to load,
    // so current displayed image is at index - 1
    return myCurrentImageIndex - 1;
}

- (NSString *)currentFilePathForPanel {
    NSInteger index = [self currentFileIndex];
    if (index < 0 || index >= (NSInteger)[myChosenFiles count]) return nil;
    return [myChosenFiles objectAtIndex:index];
}

- (void)jumpToIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)[myChosenFiles count]) {
        return;
    }
    myCurrentImageIndex = (int)index;
    [self loadNextImage];
}

- (void)jumpToPath:(NSString *)path {
    if (!path) return;

    // Find the index of the file by path
    for (NSInteger i = 0; i < (NSInteger)[myChosenFiles count]; i++) {
        NSString *filePath = [myChosenFiles objectAtIndex:i];
        if ([filePath isEqualToString:path]) {
            [self jumpToIndex:i];
            return;
        }
    }
}

@end
