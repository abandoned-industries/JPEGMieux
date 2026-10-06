//
//  FileListPanel.m
//  JPEGDeux
//
//  Quick file picker panel for navigating slideshow images
//

#import "FileListPanel.h"
#import "MediaUtils.h"

static FileListPanel *sharedInstance = nil;

// Model for outline view: represents either a folder or a file
@interface FileListItem : NSObject
@property (nonatomic, strong) NSString *displayName;  // Relative folder path or file name
@property (nonatomic, strong) NSString *fullPath;     // Full path (for files)
@property (nonatomic, assign) BOOL isFolder;
@property (nonatomic, strong) NSMutableArray *children;  // Files in folder (if folder)
@property (nonatomic, assign) NSInteger fileCount;    // Number of playable files in folder
@property (nonatomic, assign) NSInteger unplayableCount;  // Videos in folder that can't be played
@property (nonatomic, assign) BOOL unplayable;        // File row: video AVFoundation can't play
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
@property (nonatomic, strong) NSMutableArray *outlineItems;  // Root items for outline view
@property (nonatomic, strong) NSString *currentFilePath;  // Current file path for highlighting
@property (nonatomic, strong) NSString *commonRoot;  // Common root directory
@property (nonatomic, assign) BOOL showMoviesOnly;
@property (nonatomic, strong) NSMutableDictionary *itemsByPath;  // file path -> FileListItem
@property (nonatomic, assign) BOOL applyingProgrammaticSelection;  // YES while we move the selection ourselves
@end

@implementation FileListPanel

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
    [self setHidesOnDeactivate:YES];
    [self setReleasedWhenClosed:NO];

    // Dark appearance
    [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    [self setTitlebarAppearsTransparent:YES];
    [self setBackgroundColor:[NSColor colorWithWhite:0.1 alpha:0.95]];

    // Remember position
    [self setFrameAutosaveName:@"FileListPanel"];

    // Size constraints
    [self setMinSize:NSMakeSize(200, 200)];
    // No max size: big collections need a tall, wide list
}

- (NSButton *)filterCheckboxWithTitle:(NSString *)title action:(SEL)action x:(CGFloat)x {
    NSButton *box = [NSButton checkboxWithTitle:title target:self action:action];
    box.frame = NSMakeRect(x, 10, 105, 20);
    box.autoresizingMask = NSViewMaxYMargin;
    [box setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:title];
    [attrTitle addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, attrTitle.length)];
    [attrTitle addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12] range:NSMakeRange(0, attrTitle.length)];
    box.attributedTitle = attrTitle;
    [_backgroundView addSubview:box];
    return box;
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
    _moviesOnlyCheckbox = [self filterCheckboxWithTitle:@"Movies only" action:@selector(moviesOnlyChanged:) x:10];

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

// Images are trusted to NSImage. Videos go through the shared, cached AVFoundation
// check (the slideshow uses the same one, so each file is probed once).
- (BOOL)isFilePlayable:(NSString *)path {
    if ([MediaUtils isImageFile:path]) return YES;
    if ([MediaUtils isVideoFile:path]) return [MediaUtils isVideoPlayableCached:path];
    return NO;  // Unknown file types - assume not playable
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

// A video the show can't play. Cheap: the answer is cached by the filter pass.
- (BOOL)isUnplayablePath:(NSString *)path {
    return [MediaUtils isVideoFile:path] && ![MediaUtils isVideoPlayableCached:path];
}

- (void)buildOutlineViewStructure:(NSArray *)files {
    [_outlineItems removeAllObjects];
    _itemsByPath = [[NSMutableDictionary alloc] init];

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
        fileItem.unplayable = [self isUnplayablePath:filePath];

        FileListItem *folderItem = folderMap[folder];
        if (fileItem.unplayable) folderItem.unplayableCount++;
        [folderItem.children addObject:fileItem];
        _itemsByPath[filePath] = fileItem;
    }

    // Sort folders by path using localizedStandardCompare for stability
    [folderOrder sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 localizedStandardCompare:obj2];
    }];

    // Add sorted folders to outline items
    for (NSString *folder in folderOrder) {
        FileListItem *folderItem = folderMap[folder];
        folderItem.fileCount = [folderItem.children count] - folderItem.unplayableCount;
        [_outlineItems addObject:folderItem];
    }
}

- (void)filterFilesAndBuildMapping:(NSArray *)files {
    NSMutableArray *filtered = [[NSMutableArray alloc] init];

    for (NSString *path in files) {
        BOOL isVideo = [MediaUtils isVideoFile:path];
        BOOL passesFilter;
        if (_showMoviesOnly) {
            // Every video; the unplayable ones are listed grayed out
            passesFilter = isVideo;
        } else {
            // Everything we recognise; unplayable videos are listed grayed out
            passesFilter = isVideo || [MediaUtils isImageFile:path];
        }
        if (passesFilter) [filtered addObject:path];
    }

    _displayFiles = [filtered copy];

    // Compute common root and build outline structure
    _commonRoot = [self commonRootOfPaths:_displayFiles];
    [self buildOutlineViewStructure:_displayFiles];
}

- (void)refilterAndReload {
    [self filterFilesAndBuildMapping:_allFiles];
    [self reloadOutlinePreservingSelectionCallbacks];
    [self highlightCurrentFile];
}

- (void)moviesOnlyChanged:(id)sender {
    _showMoviesOnly = ([_moviesOnlyCheckbox state] == NSControlStateValueOn);
    [self refilterAndReload];
}

#pragma mark - Public Methods

- (void)updateWithFiles:(NSArray *)files currentPath:(NSString *)currentPath {
    _allFiles = [files copy];  // Store for re-filtering when checkbox changes
    _currentFilePath = currentPath;
    [self filterFilesAndBuildMapping:files];
    [self reloadOutlinePreservingSelectionCallbacks];
    [self highlightCurrentFile];
}

// reloadData and programmatic selection fire outlineViewSelectionDidChange:,
// which must never be mistaken for the user picking a file.
- (void)reloadOutlinePreservingSelectionCallbacks {
    BOOL wasApplying = _applyingProgrammaticSelection;
    _applyingProgrammaticSelection = YES;
    [_outlineView reloadData];
    _applyingProgrammaticSelection = wasApplying;
}

- (void)highlightCurrentFile {
    if (!_currentFilePath) return;
    FileListItem *fileItem = _itemsByPath[_currentFilePath];
    if (!fileItem) return;

    BOOL wasApplying = _applyingProgrammaticSelection;
    _applyingProgrammaticSelection = YES;
    // Reveal the current file's folder without collapsing whatever else the user has open
    FileListItem *folderItem = nil;
    for (FileListItem *candidate in _outlineItems) {
        if ([candidate.fullPath isEqual:[_currentFilePath stringByDeletingLastPathComponent]]) {
            folderItem = candidate;
            break;
        }
    }
    if (folderItem && ![_outlineView isItemExpanded:folderItem]) {
        [_outlineView expandItem:folderItem];
    }
    NSInteger rowIndex = [_outlineView rowForItem:fileItem];
    if (rowIndex >= 0) {
        [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
        [_outlineView scrollRowToVisible:rowIndex];
    }
    _applyingProgrammaticSelection = wasApplying;
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
    if (_allFiles) [self refilterAndReload];
}

- (void)setCurrentFilePath:(NSString *)path {
    if (!path || [path isEqual:_currentFilePath]) return;
    NSString *oldPath = _currentFilePath;
    _currentFilePath = path;
    if (![self isVisible]) return;  // highlightCurrentFile runs when the panel is shown

    // Repaint just the old and new rows (the current file is drawn yellow)
    BOOL wasApplying = _applyingProgrammaticSelection;
    _applyingProgrammaticSelection = YES;
    if (oldPath && _itemsByPath[oldPath]) [_outlineView reloadItem:_itemsByPath[oldPath]];
    if (_itemsByPath[path]) [_outlineView reloadItem:_itemsByPath[path]];
    _applyingProgrammaticSelection = wasApplying;
    [self highlightCurrentFile];
}

#pragma mark - Actions

- (void)outlineDoubleClicked:(id)sender {
    NSInteger row = [_outlineView clickedRow];
    if (row >= 0) {
        id item = [_outlineView itemAtRow:row];
        if ([item isKindOfClass:[FileListItem class]]) {
            FileListItem *listItem = (FileListItem *)item;
            if (!listItem.isFolder && !listItem.unplayable) {
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

// Unplayable videos can't be clicked, reached by arrow keys or jumped to
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    if ([item isKindOfClass:[FileListItem class]]) return !((FileListItem *)item).unplayable;
    return YES;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    if (_applyingProgrammaticSelection) return;  // we moved the selection ourselves; not a user pick
    NSInteger row = [_outlineView selectedRow];
    if (row >= 0) {
        id item = [_outlineView itemAtRow:row];
        if ([item isKindOfClass:[FileListItem class]]) {
            FileListItem *listItem = (FileListItem *)item;
            if (listItem.isFolder) {
                // Picking a folder row opens it so its files can be chosen
                if (![_outlineView isItemExpanded:listItem]) [_outlineView expandItem:listItem];
            } else if (!listItem.unplayable) {
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
            NSString *count = listItem.unplayableCount > 0
                ? [NSString stringWithFormat:@"%ld (+%ld unplayable)", (long)listItem.fileCount, (long)listItem.unplayableCount]
                : [NSString stringWithFormat:@"%ld", (long)listItem.fileCount];
            cell.stringValue = [NSString stringWithFormat:@"%@ — %@", listItem.displayName, count];
            cell.toolTip = nil;
            cell.textColor = [NSColor colorWithWhite:0.85 alpha:1.0];
            cell.font = [NSFont boldSystemFontOfSize:13];
        } else {
            // File row
            cell.stringValue = listItem.displayName;
            cell.toolTip = nil;

            if (listItem.unplayable) {
                // Listed for completeness, but the show skips it
                NSString *ext = [[listItem.fullPath pathExtension] uppercaseString];
                cell.textColor = [NSColor disabledControlTextColor];
                cell.font = [NSFont systemFontOfSize:13];
                cell.toolTip = [NSString stringWithFormat:@"Can\u2019t play this format (%@)", ext.length ? ext : @"unknown"];
            } else if ([listItem.fullPath isEqual:_currentFilePath]) {
                // Highlight current file with different color
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
                if (!listItem.isFolder && !listItem.unplayable) {
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
