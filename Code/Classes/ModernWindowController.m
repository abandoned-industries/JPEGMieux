//
//  ModernWindowController.m
//  JPEGDeux
//
//  Modern programmatic UI for the main slideshow window
//

#import "ModernWindowController.h"
#import "Master.h"
#import "BetterTable.h"

@implementation ModernWindowController

- (instancetype)initWithMaster:(Master *)master {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 850, 650)
                                                   styleMask:NSWindowStyleMaskTitled |
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskMiniaturizable |
                                                            NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];

    // Set window title with build info
    NSString *baseTitle = @"JPEGMieux";
    NSString *buildDate = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JDBuildDate"];
    NSString *buildCommit = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JDBuildCommit"];

    if (buildDate && buildCommit) {
        window.title = [NSString stringWithFormat:@"%@ — built %@ (%@)", baseTitle, buildDate, buildCommit];
    } else {
        window.title = baseTitle;
    }

    window.minSize = NSMakeSize(750, 600);
    [window setFrameAutosaveName:@"ModernMainWindow"];

    self = [super initWithWindow:window];
    if (self) {
        _master = master;
        [self setupUI];
        [window center];
    }
    return self;
}

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];

    // Create all controls
    [self createDisplayModeControls];
    [self createScalingControls];
    [self createPlaybackControls];
    [self createAppearanceControls];
    [self createImagesPanel];
    [self createBeginButton];

    // Layout using frames (simpler and more reliable)
    [self layoutControls];
}

- (void)layoutControls {
    NSView *contentView = self.window.contentView;
    CGFloat padding = 20;
    CGFloat cardSpacing = 16;
    CGFloat leftColumnWidth = 400;
    CGFloat y = contentView.bounds.size.height - padding;

    // Left column cards
    CGFloat leftX = padding;

    // Display Mode card
    y -= 80;
    NSBox *displayCard = [self createCardAtX:leftX y:y width:leftColumnWidth height:70 title:@"Display Mode"];
    _displayModeMatrix.frame = NSMakeRect(16, 10, 360, 24);
    [displayCard.contentView addSubview:_displayModeMatrix];
    [contentView addSubview:displayCard];

    // Scaling card
    y -= (70 + cardSpacing);
    NSBox *scalingCard = [self createCardAtX:leftX y:y width:leftColumnWidth height:70 title:@"Scaling"];
    _scalingMatrix.frame = NSMakeRect(16, 30, 280, 24);
    _onlyScaleDownButton.frame = NSMakeRect(16, 8, 180, 18);
    [scalingCard.contentView addSubview:_scalingMatrix];
    [scalingCard.contentView addSubview:_onlyScaleDownButton];
    [contentView addSubview:scalingCard];

    // Playback card
    y -= (170 + cardSpacing);  // Use Playback card's height (170), not Scaling's
    NSBox *playbackCard = [self createCardAtX:leftX y:y width:leftColumnWidth height:170 title:@"Playback"];
    _randomOrderButton.frame = NSMakeRect(16, 130, 120, 18);
    _loopButton.frame = NSMakeRect(150, 130, 60, 18);
    _showFileListButton.frame = NSMakeRect(230, 130, 120, 18);
    _autoAdvanceButton.frame = NSMakeRect(16, 105, 115, 18);
    _intervalField.frame = NSMakeRect(135, 103, 50, 22);
    _moviesOnlyButton.frame = NSMakeRect(230, 105, 120, 18);
    _precacheButton.frame = NSMakeRect(16, 80, 100, 18);
    _displayCommentsButton.frame = NSMakeRect(135, 80, 140, 18);
    _skipICloudFilesButton.frame = NSMakeRect(16, 55, 230, 18);

    NSTextField *filenameLabel = [NSTextField labelWithString:@"Filename:"];
    filenameLabel.frame = NSMakeRect(16, 30, 70, 17);
    filenameLabel.font = [NSFont systemFontOfSize:12];
    _filenameDisplayMatrix.frame = NSMakeRect(16, 3, 360, 22);

    [playbackCard.contentView addSubview:_randomOrderButton];
    [playbackCard.contentView addSubview:_loopButton];
    [playbackCard.contentView addSubview:_autoAdvanceButton];
    [playbackCard.contentView addSubview:_intervalField];
    [playbackCard.contentView addSubview:_precacheButton];
    [playbackCard.contentView addSubview:_displayCommentsButton];
    [playbackCard.contentView addSubview:_showFileListButton];
    [playbackCard.contentView addSubview:_moviesOnlyButton];
    [playbackCard.contentView addSubview:_skipICloudFilesButton];
    [playbackCard.contentView addSubview:filenameLabel];
    [playbackCard.contentView addSubview:_filenameDisplayMatrix];
    [contentView addSubview:playbackCard];

    // Appearance card
    y -= (50 + cardSpacing);  // Use Appearance card's height (50)
    NSBox *appearanceCard = [self createCardAtX:leftX y:y width:leftColumnWidth height:50 title:@"Appearance"];
    NSTextField *bgLabel = [NSTextField labelWithString:@"Background:"];
    bgLabel.frame = NSMakeRect(16, 12, 90, 17);
    bgLabel.font = [NSFont systemFontOfSize:13];
    _backgroundColorWell.frame = NSMakeRect(110, 8, 44, 24);
    [appearanceCard.contentView addSubview:bgLabel];
    [appearanceCard.contentView addSubview:_backgroundColorWell];
    [contentView addSubview:appearanceCard];

    // Right column - Images panel
    CGFloat rightX = padding + leftColumnWidth + 20;
    CGFloat rightWidth = contentView.bounds.size.width - rightX - padding;
    CGFloat imagesHeight = contentView.bounds.size.height - padding - 60 - padding;

    NSBox *imagesCard = [self createCardAtX:rightX y:contentView.bounds.size.height - padding - imagesHeight
                                     width:rightWidth height:imagesHeight title:@"Images"];
    imagesCard.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // Add button
    _addButton.frame = NSMakeRect(imagesCard.contentView.bounds.size.width - 70, imagesCard.contentView.bounds.size.height - 30, 60, 24);
    _addButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;

    // Recursive checkbox
    _recursiveButton.frame = NSMakeRect(16, imagesCard.contentView.bounds.size.height - 55, 250, 18);
    _recursiveButton.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;

    // Scroll view with table
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 8,
        imagesCard.contentView.bounds.size.width - 32,
        imagesCard.contentView.bounds.size.height - 70)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.documentView = _filesTable;
    _filesTable.frame = scrollView.contentView.bounds;

    [imagesCard.contentView addSubview:_addButton];
    [imagesCard.contentView addSubview:_recursiveButton];
    [imagesCard.contentView addSubview:scrollView];
    [contentView addSubview:imagesCard];

    // Begin button at bottom
    _beginButton.frame = NSMakeRect(padding, padding, contentView.bounds.size.width - 2*padding, 36);
    _beginButton.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [contentView addSubview:_beginButton];
}

- (NSBox *)createCardAtX:(CGFloat)x y:(CGFloat)y width:(CGFloat)w height:(CGFloat)h title:(NSString *)title {
    NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(x, y, w, h)];
    box.boxType = NSBoxCustom;
    box.cornerRadius = 8;
    box.fillColor = [NSColor controlBackgroundColor];
    box.borderColor = [NSColor separatorColor];
    box.borderWidth = 0.5;
    box.contentViewMargins = NSMakeSize(0, 0);
    box.titlePosition = NSNoTitle;
    return box;
}

#pragma mark - Create Controls

- (void)createDisplayModeControls {
    self.displayModeMatrix = [[NSMatrix alloc] initWithFrame:NSZeroRect
                                                       mode:NSRadioModeMatrix
                                                  cellClass:[NSButtonCell class]
                                               numberOfRows:1
                                            numberOfColumns:3];
    self.displayModeMatrix.cellSize = NSMakeSize(90, 20);
    self.displayModeMatrix.intercellSpacing = NSMakeSize(4, 0);

    NSArray *modes = @[@"Window", @"Full Screen", @"Dock"];
    NSArray *tags = @[@0, @1, @2];
    for (int i = 0; i < 3; i++) {
        NSButtonCell *cell = [self.displayModeMatrix cellAtRow:0 column:i];
        cell.title = modes[i];
        cell.tag = [tags[i] integerValue];
        cell.buttonType = NSButtonTypeRadio;
        cell.font = [NSFont systemFontOfSize:12];
    }
    [self.displayModeMatrix selectCellAtRow:0 column:0];
    self.displayModeMatrix.target = self.master;
    self.displayModeMatrix.action = @selector(setDisplayMode:);
}

- (void)createScalingControls {
    self.scalingMatrix = [[NSMatrix alloc] initWithFrame:NSZeroRect
                                                   mode:NSRadioModeMatrix
                                              cellClass:[NSButtonCell class]
                                           numberOfRows:1
                                        numberOfColumns:2];
    self.scalingMatrix.cellSize = NSMakeSize(120, 20);
    self.scalingMatrix.intercellSpacing = NSMakeSize(8, 0);

    NSButtonCell *noneCell = [self.scalingMatrix cellAtRow:0 column:0];
    noneCell.title = @"None";
    noneCell.tag = 2;
    noneCell.buttonType = NSButtonTypeRadio;
    noneCell.font = [NSFont systemFontOfSize:12];

    NSButtonCell *propCell = [self.scalingMatrix cellAtRow:0 column:1];
    propCell.title = @"Proportional";
    propCell.tag = 0;
    propCell.buttonType = NSButtonTypeRadio;
    propCell.font = [NSFont systemFontOfSize:12];

    self.scalingMatrix.target = self.master;
    self.scalingMatrix.action = @selector(setImageScaling:);

    self.onlyScaleDownButton = [NSButton checkboxWithTitle:@"Only scale down" target:self.master action:@selector(setShouldOnlyScaleDown:)];
    self.onlyScaleDownButton.font = [NSFont systemFontOfSize:12];
}

- (void)createPlaybackControls {
    self.randomOrderButton = [NSButton checkboxWithTitle:@"Random order" target:self.master action:@selector(setRandomOrder:)];
    self.randomOrderButton.font = [NSFont systemFontOfSize:12];

    self.loopButton = [NSButton checkboxWithTitle:@"Loop" target:self.master action:@selector(setLoop:)];
    self.loopButton.font = [NSFont systemFontOfSize:12];

    self.autoAdvanceButton = [NSButton checkboxWithTitle:@"Advance after" target:self.master action:@selector(setAutoAdvance:)];
    self.autoAdvanceButton.font = [NSFont systemFontOfSize:12];

    self.intervalField = [[NSTextField alloc] init];
    self.intervalField.stringValue = @"1.0";
    self.intervalField.alignment = NSTextAlignmentCenter;
    self.intervalField.font = [NSFont systemFontOfSize:12];
    self.intervalField.target = self.master;
    self.intervalField.action = @selector(setInterval:);

    self.precacheButton = [NSButton checkboxWithTitle:@"Precache" target:self.master action:@selector(setShouldPrecache:)];
    self.precacheButton.font = [NSFont systemFontOfSize:12];

    self.displayCommentsButton = [NSButton checkboxWithTitle:@"Show comments" target:self.master action:@selector(setCommentDisplay:)];
    self.displayCommentsButton.font = [NSFont systemFontOfSize:12];

    self.showFileListButton = [NSButton checkboxWithTitle:@"Show file list" target:self.master action:@selector(setShowFileList:)];
    self.showFileListButton.font = [NSFont systemFontOfSize:12];

    self.moviesOnlyButton = [NSButton checkboxWithTitle:@"Movies only" target:self.master action:@selector(setMoviesOnly:)];
    self.moviesOnlyButton.font = [NSFont systemFontOfSize:12];

    self.skipICloudFilesButton = [NSButton checkboxWithTitle:@"Skip undownloaded iCloud files" target:self.master action:@selector(setSkipICloudFiles:)];
    self.skipICloudFilesButton.font = [NSFont systemFontOfSize:12];

    self.filenameDisplayMatrix = [[NSMatrix alloc] initWithFrame:NSZeroRect
                                                           mode:NSRadioModeMatrix
                                                      cellClass:[NSButtonCell class]
                                                   numberOfRows:1
                                                numberOfColumns:3];
    self.filenameDisplayMatrix.cellSize = NSMakeSize(80, 18);
    self.filenameDisplayMatrix.intercellSpacing = NSMakeSize(4, 0);

    NSArray *titles = @[@"None", @"Name only", @"Full path"];
    for (int i = 0; i < 3; i++) {
        NSButtonCell *cell = [self.filenameDisplayMatrix cellAtRow:0 column:i];
        cell.title = titles[i];
        cell.tag = i;
        cell.buttonType = NSButtonTypeRadio;
        cell.font = [NSFont systemFontOfSize:11];
    }
    self.filenameDisplayMatrix.target = self.master;
    self.filenameDisplayMatrix.action = @selector(setFileNameDisplayType:);
}

- (void)createAppearanceControls {
    self.backgroundColorWell = [[NSColorWell alloc] init];
    self.backgroundColorWell.color = [NSColor blackColor];
}

- (void)createImagesPanel {
    self.addButton = [[NSButton alloc] init];
    self.addButton.title = @"Add...";
    self.addButton.bezelStyle = NSBezelStyleRounded;
    self.addButton.font = [NSFont systemFontOfSize:12];
    self.addButton.target = self.master;
    self.addButton.action = @selector(selectFiles:);

    self.recursiveButton = [NSButton checkboxWithTitle:@"Recursively scan subdirectories" target:self.master action:@selector(setShouldRecursivelyScanSubdirectories:)];
    self.recursiveButton.font = [NSFont systemFontOfSize:11];

    self.filesTable = [[BetterTable alloc] init];
    self.filesTable.headerView = nil;
    self.filesTable.rowHeight = 18;
    self.filesTable.intercellSpacing = NSMakeSize(3, 2);
    self.filesTable.allowsMultipleSelection = YES;
    self.filesTable.dataSource = (id)self.master;
    self.filesTable.delegate = (id)self.master;

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"filename"];
    column.editable = NO;
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.filesTable addTableColumn:column];
}

- (void)createBeginButton {
    self.beginButton = [[NSButton alloc] init];
    self.beginButton.title = @"Begin Slideshow";
    self.beginButton.bezelStyle = NSBezelStyleRounded;
    self.beginButton.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.beginButton.keyEquivalent = @"\r";
    self.beginButton.target = self.master;
    self.beginButton.action = @selector(begin:);
}

@end
