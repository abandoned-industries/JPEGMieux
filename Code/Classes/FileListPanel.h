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

+ (instancetype)sharedPanel;

// Update with the show's files (including videos it skipped as unplayable) and the
// path now showing. Unplayable videos are listed grayed out and cannot be picked.
- (void)updateWithFiles:(NSArray *)files currentPath:(NSString *)currentPath;
- (void)setCurrentFilePath:(NSString *)path;  // Path of the image now showing; never triggers a jump
- (void)highlightCurrentFile;
- (void)toggle;
- (void)setShowMoviesOnly:(BOOL)moviesOnly;

@end
