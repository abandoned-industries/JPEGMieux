//
//  ModernWindowController.h
//  JPEGDeux
//
//  Modern programmatic UI for the main slideshow window
//

#import <Cocoa/Cocoa.h>
#import "PetersTypes.h"

@class Master;

@interface ModernWindowController : NSWindowController

@property (nonatomic, weak) Master *master;

// Display mode
@property (nonatomic, strong) NSMatrix *displayModeMatrix;

// Scaling
@property (nonatomic, strong) NSMatrix *scalingMatrix;
@property (nonatomic, strong) NSButton *onlyScaleDownButton;

// Filename display
@property (nonatomic, strong) NSMatrix *filenameDisplayMatrix;

// Playback options
@property (nonatomic, strong) NSButton *randomOrderButton;
@property (nonatomic, strong) NSButton *loopButton;
@property (nonatomic, strong) NSButton *precacheButton;
@property (nonatomic, strong) NSButton *autoAdvanceButton;
@property (nonatomic, strong) NSTextField *intervalField;
@property (nonatomic, strong) NSButton *displayCommentsButton;
@property (nonatomic, strong) NSButton *showFileListButton;
@property (nonatomic, strong) NSButton *moviesOnlyButton;
@property (nonatomic, strong) NSButton *imagesOnlyButton;
@property (nonatomic, strong) NSButton *skipICloudFilesButton;

// Appearance
@property (nonatomic, strong) NSColorWell *backgroundColorWell;

// Images
@property (nonatomic, strong) NSTableView *filesTable;
@property (nonatomic, strong) NSButton *recursiveButton;

// Actions
@property (nonatomic, strong) NSButton *beginButton;
@property (nonatomic, strong) NSButton *addButton;

- (instancetype)initWithMaster:(Master *)master;
- (void)setupUI;

@end
