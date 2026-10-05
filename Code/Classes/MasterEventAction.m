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
    [panel updateWithFiles:[myCurrentShow fileList] currentIndex:[myCurrentShow currentFileIndex]];
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

- (EventAction)kbMoveToTrash:(id)param {
    NSString* path = [myCurrentShow currentPath];
    if (![path length]) {
        NSBeep();
        return eReeval;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:path];
    NSError *error = nil;

    if (![[NSFileManager defaultManager] trashItemAtURL:fileURL
                                      resultingItemURL:nil
                                                 error:&error]) {
        NSBeep();
        return eReeval;
    }

    // Remove the file from the show's internal file list
    NSInteger currentIndex = [myCurrentShow currentFileIndex];
    NSArray *showFileList = [myCurrentShow fileList];

    if (currentIndex >= 0 && currentIndex < (NSInteger)[showFileList count]) {
        // Remove from show's internal list (need to access private member)
        // Since we can't directly access myChosenFiles, we'll use KVC
        NSMutableArray *showChosenFiles = [myCurrentShow valueForKey:@"myChosenFiles"];
        [showChosenFiles removeObjectAtIndex:currentIndex];

        // Remove from Master's file hierarchy
        // Find and remove the path from myFileHierarchyArray
        [self removeFilePath:path fromHierarchy:myFileHierarchyArray];

        // Update the file list panel
        FileListPanel *panel = [FileListPanel sharedPanel];
        [panel updateWithFiles:[myCurrentShow fileList] currentIndex:[myCurrentShow currentFileIndex]];
    }

    // Advance to next image
    return eNext;
}

// Helper method to recursively remove a path from the file hierarchy
- (void)removeFilePath:(NSString *)filePath fromHierarchy:(NSMutableArray *)hierarchy {
    for (NSInteger i = [hierarchy count] - 1; i >= 0; i--) {
        id item = [hierarchy objectAtIndex:i];
        if ([item isKindOfClass:[NSString class]] && [item isEqualToString:filePath]) {
            [hierarchy removeObjectAtIndex:i];
        } else if ([item isKindOfClass:[NSMutableArray class]]) {
            [self removeFilePath:filePath fromHierarchy:item];
            // Remove empty arrays
            if ([(NSArray *)item count] == 0) {
                [hierarchy removeObjectAtIndex:i];
            }
        } else if ([item respondsToSelector:@selector(valueForKey:)]) {
            // Handle FileHierarchy objects
            NSMutableArray *files = [item valueForKey:@"myFiles"];
            if (files) {
                [self removeFilePath:filePath fromHierarchy:files];
            }
        }
    }
}

@end