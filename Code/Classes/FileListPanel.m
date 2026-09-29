//
//  FileListPanel.m
//  JPEGDeux
//
//  Quick file picker panel for navigating slideshow images
//

#import "FileListPanel.h"
#import "MediaUtils.h"

static FileListPanel *sharedInstance = nil;

// Cache validation results to avoid re-checking
static NSMutableDictionary *videoValidationCache = nil;

// Model for outline view: represents either a folder or a file
@interface FileListItem : NSObject
@property (nonatomic, strong) NSString *displayName;  // Relative folder path or file name
@property (nonatomic, strong) NSString *fullPath;     // Full path (for files)
@property (nonatomic, assign) BOOL isFolder;
@property (nonatomic, strong) NSMutableArray *children;  // Files in folder (if folder)
@property (nonatomic, assign) NSInteger fileCount;    // Number of files in folder
@end

@implementation FileListItem
@end

@interface FileListPanel ()
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSVisualEffectView *backgroundView;
@property (nonatomic, strong) NSButton *moviesOnlyCheckbox;
@property (nonatomic, strong) NSArray *allFiles;  // All files before filtering
@property (nonatomic, strong) NSArray *displayFiles;  // Filtered files for display
@property (nonatomic, strong) NSArray *originalIndexMap;  // Maps display index -> original index
@property (nonatomic, strong) NSMutableArray *outlineItems;  // Root items for outline view
@property (nonatomic, strong) NSString *currentFilePath;  // Current file path for highlighting
@property (nonatomic, strong) NSString *commonRoot;  // Common root directory
@property (nonatomic, assign) BOOL showMoviesOnly;
@end

@implementation FileListPanel

+ (void)initialize {
    if (self == [FileListPanel class]) {
        videoValidationCache = [[NSMutableDictionary alloc] init];
    }
}

+ (instancetype)sharedPanel {
    if (!sharedInstance) {
        sharedInstance = [[FileListPanel alloc] init];
    }
    return sharedInstance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(100, 100, 280, 400);
    self = [super initWithContentRect:frame
                            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self setupPanel];
        [self setupUI];
    }
    return self;
}

- (void)setupPanel {
    // Panel configuration
    [self setLevel:NSFloatingWindowLevel];
    [self setTitle:@"File List"];
    [self setMovableByWindowBackground:YES];
    [self setHidesOnDeactivate:NO];
    [self setReleasedWhenClosed:NO];

    // Dark appearance
    [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    [self setTitlebarAppearsTransparent:YES];
    [self setBackgroundColor:[NSColor colorWithWhite:0.1 alpha:0.95]];

    // Remember position
    [self setFrameAutosaveName:@"FileListPanel"];

    // Size constraints - keep it compact
    [self setMinSize:NSMakeSize(200, 200)];
    [self setMaxSize:NSMakeSize(400, 600)];
}

- (void)setupUI {
    NSView *contentView = [self contentView];

    // Visual effect background for dark blur
    _backgroundView = [[NSVisualEffectView alloc] initWithFrame:contentView.bounds];
    _backgroundView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _backgroundView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _backgroundView.material = NSVisualEffectMaterialMenu;
    _backgroundView.state = NSVisualEffectStateActive;
    [contentView addSubview:_backgroundView];

    // Movies only checkbox at bottom
    _moviesOnlyCheckbox = [NSButton checkboxWithTitle:@"Movies only" target:self action:@selector(moviesOnlyChanged:)];
    _moviesOnlyCheckbox.frame = NSMakeRect(10, 10, 150, 20);
    _moviesOnlyCheckbox.autoresizingMask = NSViewMaxYMargin;
    [_moviesOnlyCheckbox setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:@"Movies only"];
    [attrTitle addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, attrTitle.length)];
    [attrTitle addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12] range:NSMakeRange(0, attrTitle.length)];
    _moviesOnlyCheckbox.attributedTitle = attrTitle;
    [_backgroundView addSubview:_moviesOnlyCheckbox];

    // Create scroll view for outline view (above checkbox)
    CGFloat checkboxHeight = 30;
    NSRect scrollFrame = NSMakeRect(10, 10 + checkboxHeight, contentView.bounds.size.width - 20, contentView.bounds.size.height - 20 - checkboxHeight);
    _scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.hasHorizontalScroller = NO;
    _scrollView.borderType = NSNoBorder;
    _scrollView.backgroundColor = [NSColor clearColor];
    _scrollView.drawsBackground = NO;

    // Create outline view
    _outlineView = [[NSOutlineView alloc] initWithFrame:_scrollView.bounds];
    _outlineView.backgroundColor = [NSColor clearColor];
    _outlineView.headerView = nil; // No header
    _outlineView.rowHeight = 24;
    _outlineView.intercellSpacing = NSMakeSize(0, 2);
    _outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    _outlineView.delegate = self;
    _outlineView.dataSource = self;
    _outlineView.allowsMultipleSelection = NO;
    _outlineView.doubleAction = @selector(outlineDoubleClicked:);
    _outlineView.target = self;

    // File name column
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"filename"];
    column.width = scrollFrame.size.width - 20;
    column.minWidth = 100;
    column.resizingMask = NSTableColumnAutoresizingMask;

    // Style the cell
    NSTextFieldCell *cell = [[NSTextFieldCell alloc] init];
    cell.textColor = [NSColor whiteColor];
    cell.font = [NSFont systemFontOfSize:13];
    cell.lineBreakMode = NSLineBreakByTruncatingMiddle;
    column.dataCell = cell;

    [_outlineView addTableColumn:column];

    _scrollView.documentView = _outlineView;
    [_backgroundView addSubview:_scrollView];

    _outlineItems = [[NSMutableArray alloc] init];
}

#pragma mark - File Validation

- (BOOL)isFilePlayable:(NSString *)path {
    // Images are always playable (we trust NSImage to handle them)
    if ([MediaUtils isImageFile:path]) {
        return YES;
    }

    // For videos, check the cache first
    if ([MediaUtils isVideoFile:path]) {
        NSNumber *cached = videoValidationCache[path];
        if (cached) {
            return [cached boolValue];
        }

        // Validate and cache
        BOOL playable = [MediaUtils isVideoPlayable:path];
        videoValidationCache[path] = @(playable);
        return playable;
    }

    // Unknown file types - assume not playable
    return NO;
}

- (NSString *)commonRootOfPaths:(NSArray *)paths {
    if ([paths count] == 0) return nil;
    if ([paths count] == 1) return [[paths[0] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];

    NSString *first = [paths[0] stringByDeletingLastPathComponent];
    NSString *current = first;

    for (NSInteger i = 1; i < (NSInteger)[paths count]; i++) {
        NSString *folder = [paths[i] stringByDeletingLastPathComponent];

        // Find common prefix
        NSArray *currentParts = [current pathComponents];
        NSArray *folderParts = [folder pathComponents];

        NSMutableArray *commonParts = [[NSMutableArray alloc] init];
        NSInteger minParts = MIN([currentParts count], [folderParts count]);

        for (NSInteger j = 0; j < minParts; j++) {
            if ([currentParts[j] isEqual:folderParts[j]]) {
                [commonParts addObject:currentParts[j]];
            } else {
                break;
            }
        }

        if ([commonParts count] == 0) {
            return nil;  // No common root
        }

        current = [NSString pathWithComponents:commonParts];
    }

    return current;
}

- (void)buildOutlineViewStructure:(NSArray *)files {
    [_outlineItems removeAllObjects];

    // Group files by folder
    NSMutableDictionary *folderMap = [[NSMutableDictionary alloc] init];  // folder path -> FileListItem
    NSMutableArray *folderOrder = [[NSMutableArray alloc] init];  // Keep insertion order

    for (NSString *filePath in files) {
        NSString *folder = [filePath stringByDeletingLastPathComponent];

        if (!folderMap[folder]) {
            FileListItem *folderItem = [[FileListItem alloc] init];
            folderItem.fullPath = folder;
            folderItem.isFolder = YES;
            folderItem.children = [[NSMutableArray alloc] init];

            // Compute relative folder path
            if (_commonRoot && [folder hasPrefix:_commonRoot]) {
                NSString *relative = [folder substringFromIndex:[_commonRoot length]];
                if ([relative hasPrefix:@"/"]) {
                    relative = [relative substringFromIndex:1];
                }
                folderItem.displayName = [relative length] > 0 ? relative : [folder lastPathComponent];
            } else {
                folderItem.displayName = [folder lastPathComponent];
            }

            folderMap[folder] = folderItem;
            [folderOrder addObject:folder];
        }

        // Add file to folder
        FileListItem *fileItem = [[FileListItem alloc] init];
        fileItem.fullPath = filePath;
        fileItem.isFolder = NO;
        fileItem.displayName = [filePath lastPathComponent];

        FileListItem *folderItem = folderMap[folder];
        [folderItem.children addObject:fileItem];
    }

    // Sort folders by path using localizedStandardCompare for stability
    [folderOrder sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 localizedStandardCompare:obj2];
    }];

    // Add sorted folders to outline items
    for (NSString *folder in folderOrder) {
        FileListItem *folderItem = folderMap[folder];
        folderItem.fileCount = [folderItem.children count];
        [_outlineItems addObject:folderItem];
    }
}

- (void)filterFilesAndBuildMapping:(NSArray *)files currentIndex:(NSInteger)currentIndex {
    NSMutableArray *filtered = [[NSMutableArray alloc] init];
    NSMutableArray *indexMap = [[NSMutableArray alloc] init];
    NSString *newCurrentPath = nil;

    for (NSInteger i = 0; i < (NSInteger)[files count]; i++) {
        NSString *path = files[i];

        // Check if file passes the filter
        BOOL passesFilter = NO;
        if (_showMoviesOnly) {
            // Only show playable videos
            passesFilter = [MediaUtils isVideoFile:path] && [self isFilePlayable:path];
        } else {
            // Show all playable files
            passesFilter = [self isFilePlayable:path];
        }

        if (passesFilter) {
            if (i == currentIndex) {
                newCurrentPath = path;
            }
            [filtered addObject:path];
            [indexMap addObject:@(i)];
        }
    }

    _displayFiles = [filtered copy];
    _originalIndexMap = [indexMap copy];
    _currentFilePath = newCurrentPath;

    // Compute common root and build outline structure
    _commonRoot = [self commonRootOfPaths:_displayFiles];
    [self buildOutlineViewStructure:_displayFiles];
}

- (void)moviesOnlyChanged:(id)sender {
    _showMoviesOnly = ([_moviesOnlyCheckbox state] == NSControlStateValueOn);
    [self filterFilesAndBuildMapping:_allFiles currentIndex:_currentIndex];
    [_outlineView reloadData];
    [self highlightCurrentFile];
}

#pragma mark - Public Methods

- (void)updateWithFiles:(NSArray *)files currentIndex:(NSInteger)index {
    _allFiles = [files copy];  // Store for re-filtering when checkbox changes
    _currentIndex = index;
    [self filterFilesAndBuildMapping:files currentIndex:index];
    [_outlineView reloadData];
    [self highlightCurrentFile];
}

- (void)highlightCurrentFile {
    if (!_currentFilePath) return;

    // Collapse all folders first
    for (FileListItem *folderItem in _outlineItems) {
        [_outlineView collapseItem:folderItem];
    }

    // Find and expand the folder containing current file
    for (FileListItem *folderItem in _outlineItems) {
        for (FileListItem *fileItem in folderItem.children) {
            if ([fileItem.fullPath isEqual:_currentFilePath]) {
                // Expand this folder
                [_outlineView expandItem:folderItem];

                // Select and scroll to the file
                NSInteger rowIndex = [_outlineView rowForItem:fileItem];
                if (rowIndex >= 0) {
                    [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
                    [_outlineView scrollRowToVisible:rowIndex];
                }
                return;
            }
        }
    }
}

- (void)toggle {
    if ([self isVisible]) {
        [self orderOut:nil];
    } else {
        [self makeKeyAndOrderFront:nil];
        [self highlightCurrentFile];
    }
}

- (void)setShowMoviesOnly:(BOOL)moviesOnly {
    _showMoviesOnly = moviesOnly;
    [_moviesOnlyCheckbox setState:moviesOnly ? NSControlStateValueOn : NSControlStateValueOff];
    if (_allFiles) {
        [self filterFilesAndBuildMapping:_allFiles currentIndex:_currentIndex];
        [_outlineView reloadData];
        [self highlightCurrentFile];
    }
}

- (void)setCurrentIndex:(NSInteger)currentIndex {
    _currentIndex = currentIndex;
    // Find the corresponding file path
    if (currentIndex >= 0 && currentIndex < (NSInteger)[_originalIndexMap count]) {
        NSInteger originalIndex = [_originalIndexMap[currentIndex] integerValue];
        if (originalIndex >= 0 && originalIndex < (NSInteger)[_allFiles count]) {
            _currentFilePath = _allFiles[originalIndex];
        }
    }
    [_outlineView reloadData];
    [self highlightCurrentFile];
}

#pragma mark - Actions

- (void)outlineDoubleClicked:(id)sender {
    NSInteger row = [_outlineView clickedRow];
    if (row >= 0) {
        id item = [_outlineView itemAtRow:row];
        if ([item isKindOfClass:[FileListItem class]]) {
            FileListItem *listItem = (FileListItem *)item;
            if (!listItem.isFolder) {
                // File was clicked
                if ([_fileListDelegate respondsToSelector:@selector(fileListPanel:didSelectFilePath:)]) {
                    [_fileListDelegate fileListPanel:self didSelectFilePath:listItem.fullPath];
                }
            }
        }
    }
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        // Root level - number of folders
        return [_outlineItems count];
    }

    if ([item isKindOfClass:[FileListItem class]]) {
        FileListItem *listItem = (FileListItem *)item;
        if (listItem.isFolder) {
            return [listItem.children count];
        }
    }

    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        // Root level
        if (index >= 0 && index < (NSInteger)[_outlineItems count]) {
            return _outlineItems[index];
        }
        return nil;
    }

    if ([item isKindOfClass:[FileListItem class]]) {
        FileListItem *listItem = (FileListItem *)item;
        if (listItem.isFolder && index >= 0 && index < (NSInteger)[listItem.children count]) {
            return listItem.children[index];
        }
    }

    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if ([item isKindOfClass:[FileListItem class]]) {
        FileListItem *listItem = (FileListItem *)item;
        return listItem.isFolder;
    }
    return NO;
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [_outlineView selectedRow];
    if (row >= 0) {
        id item = [_outlineView itemAtRow:row];
        if ([item isKindOfClass:[FileListItem class]]) {
            FileListItem *listItem = (FileListItem *)item;
            if (!listItem.isFolder) {
                // File was selected
                if ([_fileListDelegate respondsToSelector:@selector(fileListPanel:didSelectFilePath:)]) {
                    [_fileListDelegate fileListPanel:self didSelectFilePath:listItem.fullPath];
                }
            }
        }
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTextField *cell = [outlineView makeViewWithIdentifier:@"FileCell" owner:self];

    if (!cell) {
        cell = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 24)];
        cell.identifier = @"FileCell";
        cell.bordered = NO;
        cell.editable = NO;
        cell.selectable = NO;
        cell.drawsBackground = NO;
        cell.textColor = [NSColor whiteColor];
        cell.font = [NSFont systemFontOfSize:13];
        cell.lineBreakMode = NSLineBreakByTruncatingMiddle;
    }

    if ([item isKindOfClass:[FileListItem class]]) {
        FileListItem *listItem = (FileListItem *)item;

        if (listItem.isFolder) {
            // Folder row - bold and show file count
            cell.stringValue = [NSString stringWithFormat:@"%@ — %ld", listItem.displayName, (long)listItem.fileCount];
            cell.textColor = [NSColor systemGrayColor];
            cell.font = [NSFont boldSystemFontOfSize:13];
        } else {
            // File row
            cell.stringValue = listItem.displayName;

            // Highlight current file with different color
            if ([listItem.fullPath isEqual:_currentFilePath]) {
                cell.textColor = [NSColor systemYellowColor];
                cell.font = [NSFont boldSystemFontOfSize:13];
            } else {
                cell.textColor = [NSColor whiteColor];
                cell.font = [NSFont systemFontOfSize:13];
            }
        }
    }

    return cell;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    return 24;
}

#pragma mark - Keyboard handling

- (void)keyDown:(NSEvent *)event {
    unichar key = [[event characters] characterAtIndex:0];

    // Allow up/down arrow keys to navigate
    if (key == NSUpArrowFunctionKey || key == NSDownArrowFunctionKey) {
        [_outlineView keyDown:event];
        return;
    }

    // Left/Right arrow keys for collapse/expand
    if (key == NSLeftArrowFunctionKey || key == NSRightArrowFunctionKey) {
        NSInteger row = [_outlineView selectedRow];
        if (row >= 0) {
            id item = [_outlineView itemAtRow:row];
            if ([item isKindOfClass:[FileListItem class]]) {
                FileListItem *listItem = (FileListItem *)item;
                if (listItem.isFolder) {
                    if (key == NSLeftArrowFunctionKey) {
                        [_outlineView collapseItem:item];
                    } else {
                        [_outlineView expandItem:item];
                    }
                    return;
                }
            }
        }
        [_outlineView keyDown:event];
        return;
    }

    // Enter/Return selects the current row (if it's a file)
    if (key == '\r' || key == 0x03) {
        NSInteger row = [_outlineView selectedRow];
        if (row >= 0) {
            id item = [_outlineView itemAtRow:row];
            if ([item isKindOfClass:[FileListItem class]]) {
                FileListItem *listItem = (FileListItem *)item;
                if (!listItem.isFolder) {
                    if ([_fileListDelegate respondsToSelector:@selector(fileListPanel:didSelectFilePath:)]) {
                        [_fileListDelegate fileListPanel:self didSelectFilePath:listItem.fullPath];
                    }
                }
            }
        }
        return;
    }

    // Tab or Escape closes the panel
    if (key == '\t' || key == 0x1B) {
        [self orderOut:nil];
        return;
    }

    [super keyDown:event];
}

@end
