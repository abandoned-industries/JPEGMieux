//
//  SlideShow.h
//  JPEGDeux
//
//  Created by Peter on Tue Sep 04 2001.
//

#import <Cocoa/Cocoa.h>
#import "PetersTypes.h"

//JPEGDeux will warn at this number of MB for precacheing
#define WARNING_LEVEL 75.

// Number of images to preload ahead/behind current position
#define PRELOAD_AHEAD 3
#define PRELOAD_BEHIND 1

@interface SlideShow : NSObject {
    BOOL myDontShowComment;
    NSWindow* myCommentWindow;
    NSTextField* myCommentField;
    CommentStyle myCommentStyle;
    NSMutableArray* myChosenFiles;
    NSArray* myOriginalFiles;           // the list as the show began, in order
    NSMutableSet* mySkippedFiles;       // unplayable videos dropped from myChosenFiles
    BOOL myWasShuffled;
    int myCurrentImageIndex;
    NSImage* myNextImage;
    NSURL* myNextVideoURL;  // For video files
    BOOL myNextIsVideo;     // Flag to indicate if next file is video
    NSMutableArray* myCachedImages;
    NSMutableArray* myCachedImageComments;
    BetterImageScaling myScaling;
    FileNameDisplay myFileNameDisplay;
    float myRotation;
    NSString* myFileComments;

    // Sliding window cache for efficient memory usage
    NSCache* myImageCache;
    BOOL myUseSmartCache;
}

//currently recognized params: FadeTransition => NSValue of should fade
- (id)initWithParams:(NSDictionary*)params;

- (void)beginShow:(NSArray*)files;
- (BOOL)advanceImage:(CFTimeInterval*)timeOfDisplay;
- (void)loadNextImage;
- (void)rewind:(int)count;
- (void)reshuffle;

- (void)toggleCommentWindow;

- (void)rotate:(int)v;

- (NSString*)currentPath;

// Drops the image on screen from the show (after its file was trashed). Returns NO if
// the show is now empty. *wasLast says it was the last image, in which case nothing
// follows it. Otherwise the next image to be shown is the one that followed it.
- (BOOL)removeCurrentFile:(BOOL*)wasLast;

- (void)setImageScaling:(BetterImageScaling)scaling;
- (BetterImageScaling)imageScaling;

- (void)setCommentStyle:(CommentStyle)style;

- (void)setFileNameDisplayType:(FileNameDisplay)displayType;

- (NSSize)displaySizeForSize:(NSSize)size;

+ (int)tagNumber;

//SlideShow just ignores, subclasses can override
- (void)setBackgroundColor:(NSColor*)color;
- (void)setVideoURL:(NSURL*)url;
- (void)redisplay;
- (void)flipHorizontal;
- (void)flipVertical;

//subclasses can override
- (long)estimatedSizeOfCachedImages;

- (void)preload;

// Called when slideshow ends - subclasses should override to close windows and clean up
- (void)endShow;

// Smart caching - preloads next few images in background instead of all at once
- (void)enableSmartCache;
- (void)preloadNearbyImages;
- (NSImage *)cachedImageAtIndex:(NSInteger)index;

// File list navigation
- (NSArray *)fileList;
// fileList plus the unplayable videos the show skipped, in their original places
- (NSArray *)fileListIncludingSkipped;
- (NSInteger)currentFileIndex;
- (NSString *)currentFilePathForPanel;
- (void)jumpToIndex:(NSInteger)index;
- (void)jumpToPath:(NSString *)path;

@end
