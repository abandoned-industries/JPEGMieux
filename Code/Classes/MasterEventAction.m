//
//  MasterEventAction.m
//  JPEGDeux 2
//
//  Created by peter on Sat Jul 20 2002.
//  This code is released under the Modified BSD license
//

#import "Master.h"
#import "MasterEventAction.h"
#import "SlideShow.h"
#import "FileListPanel.h"

@implementation Master (MasterEventAction)

- (EventAction)kbNextPic:(id)param {
    return eNext;
}

- (EventAction)kbPrevPic:(id)param {
    [myCurrentShow rewind:2];
    return ePrev;
}

- (EventAction)kbEndShow:(id)param {
    return eStop;
}

- (EventAction)kbToggleAdvance:(id)param {
    myShouldAutoAdvance=!myShouldAutoAdvance;
    return eReeval;
}

- (EventAction)kbIncreaseSpeed:(id)param {
    myTimeInterval=ClampedAdvanceInterval(myTimeInterval*.75);
    return eReeval;
}

- (EventAction)kbDecreaseSpeed:(id)param {
    myTimeInterval=ClampedAdvanceInterval(ClampedAdvanceInterval(myTimeInterval)*1.3333333333333333);
    return eReeval;
}

- (EventAction)kbToggleComments:(id)param {
    [myCurrentShow toggleCommentWindow];
    return eReeval;
}

- (EventAction)kbToggleFileList:(id)param {
    FileListPanel *panel = [FileListPanel sharedPanel];
    panel.fileListDelegate = self;
    [panel setShowMoviesOnly:myMoviesOnly];
    [panel updateWithFiles:[myCurrentShow fileListIncludingSkipped] currentPath:[myCurrentShow currentFilePathForPanel]];
    [panel toggle];
    return eReeval;
}

- (EventAction)kbCycleFilename:(id)param {
    // Cycle through: None (0) -> Name (1) -> Path (2) -> None (0)
    myFileNameDisplay = (myFileNameDisplay + 1) % 3;
    [myCurrentShow setFileNameDisplayType:myFileNameDisplay];
    [myCurrentShow redisplay];
    return eReeval;
}

- (EventAction)kbRotateCW:(id)param {
    [myCurrentShow rotate:3];
    [myCurrentShow redisplay];
    return eReeval;
}

- (EventAction)kbRotateCCW:(id)param {
    [myCurrentShow rotate:1];
    [myCurrentShow redisplay];
    return eReeval;
}

// Removes a path from the hierarchy of top-level files and folders. A file is
// an NSString; a folder is an array of {path, contents}. Folders stay, even if
// they end up empty, so their {path, contents} shape is never broken.
static BOOL removePathFromHierarchy(NSString* path, NSMutableArray* items) {
    NSString* target=[path stringByStandardizingPath];
    for (NSInteger i=(NSInteger)[items count]-1; i>=0; i--) {
        id item=items[i];
        if ([item isKindOfClass:[NSString class]]) {
            if ([item isEqualToString:path] || [[item stringByStandardizingPath] isEqualToString:target]) {
                [items removeObjectAtIndex:i];
                return YES;
            }
        } else if ([item isKindOfClass:[NSMutableArray class]] && [item count] >= 2) {
            id contents=[item contents];
            if ([contents isKindOfClass:[NSMutableArray class]] && removePathFromHierarchy(path, contents)) return YES;
        }
    }
    return NO;
}

- (EventAction)kbMoveToTrash:(id)param {
    NSString* path=[myCurrentShow currentPath];
    if (![path length] || [path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        NSBeep();
        return eReeval;
    }

    NSError* error=nil;
    if (![[NSFileManager defaultManager] trashItemAtURL:[NSURL fileURLWithPath:path]
                                       resultingItemURL:nil
                                                  error:&error]) {
        NSBeep();
        return eReeval;
    }

    BOOL removedLast;
    BOOL anyLeft=[myCurrentShow removeCurrentFile:&removedLast];
    removePathFromHierarchy(path, myFileHierarchyArray);
    [myFilesTable reloadData];

    if (!anyLeft) return eStop;

    FileListPanel* panel=[FileListPanel sharedPanel];
    [panel updateWithFiles:[myCurrentShow fileListIncludingSkipped] currentPath:[myCurrentShow currentFilePathForPanel]];

    // Trashed the last picture: step back to the new last one instead of ending the show
    if (removedLast) {
        [myCurrentShow rewind:1];
        return ePrev;
    }
    return eNext;
}

@end