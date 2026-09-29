#import "PrefsManager.h"
#import "Master.h"
#import "MasterEventAction.h"

static NSString* const KeyBindingsKey = @"KeyBindings";

enum {
    EscapeKey = 0x1B
};

static NSString* charToString(unichar c) {
    return [NSString stringWithCharacters:&c length:1];
}

#define SEL2STR(x) NSStringFromSelector(@selector(x))

//an ugly hack.  Above is better, but it's not a constant expression :(
//#define PASTE(a,b) a##b
//#define SEL2STR(x) PASTE(@,#x)

NSString* displayers[]={
    @"Skip to next picture",
    @"Skip to previous picture",
    @"End show",
    @"Toggle auto-advance",
    @"Increase show speed",
    @"Decrease show speed",
    @"Toggle comment window",
    @"Toggle file list",
    @"Cycle filename display"
};

NSString* selectors[sizeof displayers / sizeof *displayers];


static NSString* displayStringForKey(unichar key) {
    //assume function keys are contiguous
    if (key >= NSF1FunctionKey && key <= NSF35FunctionKey) {
        return [NSString stringWithFormat:@"F%d", key-NSF1FunctionKey+1];
    }
    switch (key) {
        case ' ': return @"Space";
        case '\r': return @"Return";
        case 0x7F: return @"Delete";
        case 0x03: return @"Enter";
        case EscapeKey: return @"Esc";
        case NSRightArrowFunctionKey: return charToString(0x2192);
        case NSLeftArrowFunctionKey: return charToString(0x2190);
        case NSUpArrowFunctionKey: return charToString(0x2191);
        case NSDownArrowFunctionKey: return charToString(0x2193);
        case NSInsertFunctionKey: return @"Ins";
        case NSDeleteFunctionKey: return @"Del";
        case NSHomeFunctionKey: return @"Home";
        case NSEndFunctionKey: return @"End";
        case NSPageUpFunctionKey: return @"PgUp";
        case NSPageDownFunctionKey: return @"PgDn";
        case NSPrintScreenFunctionKey: return @"PrScn";
        case NSScrollLockFunctionKey: return @"ScrLk";
        case NSPauseFunctionKey: return @"Pause";
        case NSSysReqFunctionKey: return @"SysRq";
        case NSBreakFunctionKey: return @"Break";
        case NSResetFunctionKey: return @"Reset";
        case NSStopFunctionKey: return @"Stop";
        case NSMenuFunctionKey: return @"Menu";
        case NSUserFunctionKey: return @"User";
        case NSSystemFunctionKey: return @"Sys";
        case NSPrintFunctionKey: return @"Print";
        case NSClearLineFunctionKey: return @"ClrLn";
        case NSClearDisplayFunctionKey: return @"ClrDs";
        case NSInsertLineFunctionKey: return @"InsLn";
        case NSDeleteLineFunctionKey: return @"DelLn";
        case NSInsertCharFunctionKey: return @"InsCh";
        case NSDeleteCharFunctionKey: return @"DelCh";
        case NSPrevFunctionKey: return @"Prev";
        case NSNextFunctionKey: return @"Next";
        case NSSelectFunctionKey: return @"Sel";
        case NSExecuteFunctionKey: return @"Exec";
        case NSUndoFunctionKey: return @"Undo";
        case NSRedoFunctionKey: return @"Redo";
        case NSFindFunctionKey: return @"Find";
        case NSHelpFunctionKey: return @"Help";
        case NSModeSwitchFunctionKey: return @"MdSwc";
        default: return charToString(key);
    }
}

@implementation PrefsManager

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadPrefs];
    }
    return self;
}

- (void)loadPrefs {
    NSUserDefaults* prefs=[NSUserDefaults standardUserDefaults];
    NSData* defs;
    myKeyBindings=nil;
    defs=[prefs objectForKey:KeyBindingsKey];
    if (defs==nil) [self revertToDefaults:self];
    else {
        NSError *error = nil;
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [KeyBinding class], [NSNull class], [NSString class], nil];
        NSArray* uncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:defs error:&error];
        if (error || !uncoded) {
            [self revertToDefaults:self];
        } else {
            // Older versions saved bindings for actions that no longer exist
            // (move to trash, rotate, flip, ...). Drop anything Master can't perform.
            myKeyBindings=[[NSMutableArray alloc] initWithCapacity:[uncoded count]];
            for (id item in uncoded) {
                if (![item isKindOfClass:[KeyBinding class]]) continue;
                KeyBinding* kb=item;
                if (kb->action && [Master instancesRespondToSelector:kb->action]) {
                    [myKeyBindings addObject:kb];
                }
            }
        }
    }
}

- (void)savePrefs {
    NSData* defs;
    NSUserDefaults* prefs=[NSUserDefaults standardUserDefaults];
    if (! myKeyBindings) [self revertToDefaults:self];
    NSError *error = nil;
    defs = [NSKeyedArchiver archivedDataWithRootObject:myKeyBindings requiringSecureCoding:NO error:&error];
    if (defs) {
        [prefs setObject:defs forKey:KeyBindingsKey];
        [prefs synchronize];
    }
}


- (void)awakeFromNib {
    if (! mySelectorDisplayStrings) {
        unsigned i;
        NSPopUpButtonCell* button;
        i=0;
        selectors[i++]=SEL2STR(kbNextPic:);
        selectors[i++]=SEL2STR(kbPrevPic:);
        selectors[i++]=SEL2STR(kbEndShow:);
        selectors[i++]=SEL2STR(kbToggleAdvance:);
        selectors[i++]=SEL2STR(kbIncreaseSpeed:);
        selectors[i++]=SEL2STR(kbDecreaseSpeed:);
        selectors[i++]=SEL2STR(kbToggleComments:);
        selectors[i++]=SEL2STR(kbToggleFileList:);
        selectors[i++]=SEL2STR(kbCycleFilename:);
        mySelectorDisplayStrings=[[NSDictionary alloc] initWithObjects:displayers
                                                               forKeys:selectors
                                                                 count:sizeof selectors/sizeof *selectors];
        button=[[NSPopUpButtonCell alloc] initTextCell:displayers[0] pullsDown:NO];
        for (i=1; i < sizeof displayers / sizeof *displayers; i++) {
            [button addItemWithTitle:displayers[i]];
        }
        [button setControlSize:NSControlSizeSmall];
        [button setFont:[NSFont systemFontOfSize:11]];
        [[myTable tableColumnWithIdentifier:@"action"] setDataCell:button];
        [myTable setTarget:self];
        [myTable setDoubleAction:@selector(changeKeyBinding:)];
        [myFieldInstructions setStringValue:@""];
        [self loadPrefs];
    }
}

- (NSString*)displayStringForSelector:(SEL)selector {
    return [mySelectorDisplayStrings objectForKey:NSStringFromSelector(selector)];
}


- (IBAction)cancel:(id)sender {
    [myWindow orderOut:self];
}

- (BOOL)validatePrefs {
    NSArray* sorted=[myKeyBindings sortedArrayUsingSelector:@selector(comparer:)];
    long i, max=[sorted count];
    unichar lastKey=0;
    for (i=0; i<max; i++) {
        KeyBinding* kb= sorted[i];
        if (kb->key==lastKey) break;
        lastKey=kb->key;
    }
    if (i < max) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Duplicate actions";
        alert.informativeText = @"Multiple actions have been assigned to the same key! "
                                @"Only one action will take effect.  Are you sure you wish to continue?";
        [alert addButtonWithTitle:@"Continue"];
        [alert addButtonWithTitle:@"Cancel"];
        NSModalResponse result = [alert runModal];
        return result == NSAlertFirstButtonReturn;
    }
    else return YES;
}

- (IBAction)OK:(id)sender {
    if ([self validatePrefs]) {
        [self savePrefs];
        [myWindow orderOut:self];
    }
}

- (IBAction)revertToDefaults:(id)sender {
    // Only include keybindings that actually work
    myKeyBindings=[[NSMutableArray alloc] initWithObjects:
        [KeyBinding bindingWithKey:NSRightArrowFunctionKey action:@selector(kbNextPic:)],
        [KeyBinding bindingWithKey:NSDownArrowFunctionKey action:@selector(kbNextPic:)],
        [KeyBinding bindingWithKey:NSLeftArrowFunctionKey action:@selector(kbPrevPic:)],
        [KeyBinding bindingWithKey:NSUpArrowFunctionKey action:@selector(kbPrevPic:)],
        [KeyBinding bindingWithKey:EscapeKey action:@selector(kbEndShow:)],
        [KeyBinding bindingWithKey:' ' action:@selector(kbToggleAdvance:)],
        [KeyBinding bindingWithKey:'\t' action:@selector(kbToggleFileList:)],
        [KeyBinding bindingWithKey:'p' action:@selector(kbCycleFilename:)],
        NULL];
    [myTable reloadData];
}

- (IBAction)editPrefs:(id)sender {
    [self loadPrefs];
    [myWindow makeKeyAndOrderFront:self];
}

- (NSUInteger)numberOfRowsInTableView:(NSTableView*)view {
    return [myKeyBindings count];
}

- (id)tableView:(NSTableView*)view objectValueForTableColumn:(NSTableColumn*)col row:(int)row {
    KeyBinding* kb= myKeyBindings[row];
    if ([[col identifier] isEqualToString:@"action"]) {
        int i;
        NSString* sel=NSStringFromSelector(kb->action);
        for (i=0; i < sizeof selectors / sizeof *selectors; i++) {
            if ([sel isEqualToString:selectors[i]]) return @(i);
        }
        return NULL;
    }
    else return displayStringForKey(kb->key);
}

- (void)tableView:(NSTableView*)view setObjectValue:(id)value forTableColumn:(NSTableColumn*)column row:(int)row {
    KeyBinding* kb=[myKeyBindings objectAtIndex:row];
    if ([[column identifier] isEqualToString:@"action"]) {
        SEL newSel=NSSelectorFromString(selectors[[value intValue]]);
        kb->action=newSel;
    }
}

- (void)setKeyBinding:(NSString*)chars {
    NSInteger row=[myTable selectedRow];
    KeyBinding* kb= myKeyBindings[row];
    kb->key=[chars characterAtIndex:0];
    [myTable reloadData];
}

- (void)changeKeyBinding:(id)sender {
    NSApplication* app = [NSApplication sharedApplication];
    NSEvent* event;
    [NSCursor hide];
    [myFieldInstructions setStringValue:@"Hit any key to change the binding for this action"];
    event=[app nextEventMatchingMask: NSEventMaskKeyDown
                           untilDate:[NSDate distantFuture]
                              inMode:NSEventTrackingRunLoopMode
                             dequeue:YES];
    [NSCursor unhide];
    [myFieldInstructions setStringValue:@""];
    [self setKeyBinding:[event charactersIgnoringModifiers]];
}

- (void)deleteRowsFromView:(NSTableView*)view {
    if ([view numberOfSelectedRows]) {
        NSInteger row=[view selectedRow];
        [myKeyBindings removeObjectAtIndex:(NSUInteger) row];
        [view reloadData];
    }
    else NSBeep();
}

- (IBAction)addKeyBinding:(id)sender {
    [myKeyBindings addObject:[KeyBinding bindingWithKey:'0' action:NSSelectorFromString(selectors[0])]];
    [myTable reloadData];
}

- (SEL)selectorForKey:(unichar)key withParam:(id*)param {
    NSInteger i, max=[myKeyBindings count];
    for (i=0; i<max; i++) {
        KeyBinding* kb= myKeyBindings[i];
        if (kb->key == key) {
            if (param) *param=kb->param;
            return kb->action;
        }
    }
    return NULL;
}

@end

@implementation KeyBinding

+ (KeyBinding*)bindingWithKey:(unichar)nkey action:(SEL)naction {
    KeyBinding* kb=[[self alloc] init];
    kb->action=naction;
    kb->key=nkey;
    return kb;
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        NSString *actionString = [coder decodeObjectForKey:@"action"];
        if (actionString) {
            action = NSSelectorFromString(actionString);
        }
        key = (unichar)[coder decodeIntegerForKey:@"key"];
        param = [coder decodeObjectForKey:@"param"];
        if ([param isKindOfClass:[NSNull class]]) {
            param = nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:NSStringFromSelector(action) forKey:@"action"];
    [coder encodeInteger:key forKey:@"key"];
    if (param) {
        [coder encodeObject:param forKey:@"param"];
    } else {
        [coder encodeObject:[NSNull null] forKey:@"param"];
    }
}

- (NSComparisonResult)comparer:(KeyBinding*)keyBinding {
    if (key < keyBinding->key) return NSOrderedAscending;
    else if (key==keyBinding->key) return NSOrderedSame;
    else return NSOrderedDescending;
}

@end
