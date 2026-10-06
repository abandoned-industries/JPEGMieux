//
//  FileHierarchySupport.m
//  JPEGDeux 2
//
//  Created by peter on Tue Jul 09 2002.
//  This code is released under the Modified BSD license
//

#import "FileHierarchySupport.h"
#import "StringAdditions.h"
#import "DataAlias.h"
#import "MediaUtils.h"
#import <sys/stat.h>

static void flattenHierarchy(id hierarchy, NSMutableArray* array) {
    if (! [hierarchy isFolder]) [array addObject:hierarchy];
    else {
        NSArray* contents = [hierarchy contents];
        long i, max=[contents count];
        for (i=0; i<max; i++) {
            flattenHierarchy([contents objectAtIndex:i], array);
        }
    }
}

// Folders nested deeper than this are skipped; no real library gets near it.
static const int kMaxHierarchyDepth = 64;

// Identity of a directory (device and inode of what it really is), so a symlink
// or Finder alias that leads back to an ancestor is recognised as a loop.
static NSString* directoryIdentity(NSString* path) {
    struct stat st;
    if (stat([path fileSystemRepresentation], &st) != 0) return nil;
    return [NSString stringWithFormat:@"%d:%llu", (int)st.st_dev, (unsigned long long)st.st_ino];
}

// path must already be alias-resolved and known to be a directory.
// ancestors holds the identities of the directories currently being scanned
// above this one. Returns nil if the directory should be skipped.
static NSMutableArray* scanDirectory(NSString* path, BOOL recursive, int depth, NSMutableSet* ancestors) {
    if (depth >= kMaxHierarchyDepth) return nil;
    NSString* identity = directoryIdentity(path);
    if (identity == nil || [ancestors containsObject:identity]) return nil;
    [ancestors addObject:identity];

    NSFileManager* filer = [NSFileManager defaultManager];
    NSError* error = nil;
    // The file system returns entries in no defined order; sort them the
    // way Finder does ("2" before "10", case-insensitive).
    NSArray* dirContents = [[filer contentsOfDirectoryAtPath:path error:&error]
        sortedArrayUsingSelector:@selector(localizedStandardCompare:)];

    NSMutableArray* hierarchyContents = [NSMutableArray arrayWithCapacity:[dirContents count]];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:2];
    [result setFilename:path];
    for (NSString* fileName in dirContents) {
        @autoreleasepool {
            NSString* filePath = [path stringByAppendingPathComponent:fileName];
            BOOL fileIsDir = NO;
            filePath = [filePath resolveAliasesIsDir:&fileIsDir];
            if (filePath == nil) continue;

            if (fileIsDir) {
                // Packages (iMovie and Final Cut libraries, apps, ...) are opaque.
                NSNumber* isPackage = nil;
                [[NSURL fileURLWithPath:filePath] getResourceValue:&isPackage forKey:NSURLIsPackageKey error:nil];
                if ([isPackage boolValue]) {
                    if ([MediaUtils isMediaFile:filePath]) [hierarchyContents addObject:filePath];
                } else if (recursive) {
                    NSMutableArray* inner = scanDirectory(filePath, recursive, depth + 1, ancestors);
                    // only add the inner directory if it has files in it
                    if (inner && [[inner contents] count] > 0) [hierarchyContents addObject:inner];
                } else {
                    // Non-recursive: still show subdirectories but don't scan their contents
                    NSMutableArray* emptyDir = [NSMutableArray arrayWithCapacity:2];
                    [emptyDir addObject:filePath];
                    [emptyDir addObject:[NSMutableArray array]];
                    [hierarchyContents addObject:emptyDir];
                }
            } else if ([MediaUtils isMediaFile:filePath]) {
                [hierarchyContents addObject:filePath];
            }
        }
    }
    [result setContents:hierarchyContents];
    [ancestors removeObject:identity];
    return result;
}

@implementation FileHierarchy

+ (id)hierarchyWithPath:(NSString*)path recursive:(BOOL)recursive {
    BOOL isDir = NO;
    path = [path resolveAliasesIsDir:&isDir];
    if (path == nil) return nil;
    if (isDir) {
        return scanDirectory(path, recursive, 0, [NSMutableSet set]);
    }
    // Use MediaUtils for comprehensive image and video detection
    return [MediaUtils isMediaFile:path] ? (id)path : nil;
}

+ (NSMutableArray*)flattenHierarchy:(id)hierarchy {
    NSMutableArray* arr=[NSMutableArray array];
    flattenHierarchy(hierarchy, arr);
    return arr;
}

@end

@implementation NSArray (FileHierarchySupport)

- (NSString*)filename {
    return [self objectAtIndex:0];
}

- (NSMutableArray*)contents {
    return [self objectAtIndex:1];
}

- (BOOL)isFolder {
    return YES;
}

- (id)alias {
    NSArray* oldContents=[self contents];
    long i, max=[oldContents count];
    NSData* path;
    NSMutableArray* contents=[NSMutableArray arrayWithCapacity:max];
    path=[[self filename] alias];
    for (i=0; i<max; i++) {
        [contents addObject:[[oldContents objectAtIndex:i] alias]];
    }
    return [NSMutableArray arrayWithObjects:path, contents, nil];
}

- (id)unalias {
    NSArray* oldContents=[self contents];
    long i, max=[oldContents count];
    NSString* path;
    NSMutableArray* contents=[NSMutableArray arrayWithCapacity:max];
    path=[[self objectAtIndex:0] unalias];
    for (i=0; i<max; i++) {
        [contents addObject:[[oldContents objectAtIndex:i] unalias]];
    }
    return [NSMutableArray arrayWithObjects:path, contents, nil];
}

- (BOOL)isAliased {
    return [[self objectAtIndex:0] isAliased];
}

@end

@implementation NSMutableArray (FileHierarchySupport)

- (void)setFilename:(NSString*)name {
    if ([self count] > 0) [self replaceObjectAtIndex:0 withObject:name];
    else [self addObject:name];
}

- (void)setContents:(NSArray*)contents {
    if ([self count] == 0) NSLog(@"Bad setContents call, before filename");
    else if ([self count] == 1) [self addObject:[NSMutableArray arrayWithArray:contents]];
    else [self replaceObjectAtIndex:1 withObject:[NSMutableArray arrayWithArray:contents]];
}

- (BOOL)removeHierarchy:(id)item {
    NSMutableArray* contents=[self contents];
    long i, max=[contents count];
    for (i=0; i<max; i++) {
        id hierarchy=[contents objectAtIndex:i];
        if ([hierarchy isEqual:item]) {
            [contents removeObjectAtIndex:i];
            return YES;
        }
        else if ([hierarchy removeHierarchy:item]) return YES;
    }
    return NO;
}

@end

@implementation NSString (FileHierarchySupport)

- (NSString*)filename {
    return self;
}

- (BOOL)isFolder {
    return NO;
}

- (BOOL)removeHierarchy:(id)item {
    return NO;
}

- (id)alias {
    if ([self hasPrefix:@"http://"]) return self;
    else return [NSData aliasForPath:self];
}

- (BOOL)isAliased {
    return NO;
}

@end

@implementation NSData (FlieHierarchySupport)

- (id)unalias {
    return [self pathForAlias];
}

- (BOOL)isAliased {
    return YES;
}

@end
