//
//  FileListPanel.h
//  JPEGDeux
//
//  Quick file picker panel for navigating slideshow images
//

#import <Cocoa/Cocoa.h>

@class SlideShow;

@protocol FileListPanelDelegate <NSObject>
- (void)fileListPanel:(id)panel didSelectFilePath:(NSString *)path;
@end

@interface FileListPanel : NSPanel <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, weak) id<FileListPanelDelegate> fileListDelegate;
@property (nonatomic, strong, readonly) NSArray *displayFiles;  // Validated files for display
@property (nonatomic, assign) NSInteger currentIndex;  // Index in original (unfiltered) array

+ (instancetype)sharedPanel;

// Update with file list - will filter out unplayable video files
- (void)updateWithFiles:(NSArray *)files currentIndex:(NSInteger)index;
- (void)highlightCurrentFile;
- (void)toggle;
- (void)setShowMoviesOnly:(BOOL)moviesOnly;

@end
