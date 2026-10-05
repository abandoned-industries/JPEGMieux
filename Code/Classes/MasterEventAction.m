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

@end