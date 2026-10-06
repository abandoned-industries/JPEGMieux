//
//  StringAdditions.m
//  JPEGDeux
//
//  Created by Peter on Wed Sep 07 2001.
//  Updated for modern macOS using NSURL APIs


#import "StringAdditions.h"

@implementation NSString (StringAdditions)

//returns a path to the file pointed at by self if self is an alias, self otherwise
//yes, we do follow chains of aliases
//returns nil if self cannot be resolved.  Does not attempt to mount volumes.
//if isDir is not nil, returns whether or not the resolved file is a directory
- (NSString*)resolveAliasesIsDir:(BOOL*)pIsDir {
    // Alias chains longer than this are treated as unresolvable (also stops alias loops).
    static const int kMaxAliasHops = 8;
    NSArray *keys = @[NSURLIsAliasFileKey, NSURLIsDirectoryKey];

    NSURL *url = [NSURL fileURLWithPath:self];
    if (!url) {
        return nil;
    }

    NSDictionary *values = [url resourceValuesForKeys:keys error:nil];
    if (!values) {
        return nil;
    }

    // Only Finder aliases need resolving; resolving is expensive and touches
    // the volume, so everything else is used as is.
    int hops = 0;
    BOOL resolved = NO;
    while ([values[NSURLIsAliasFileKey] boolValue]) {
        if (++hops > kMaxAliasHops) {
            return nil;
        }
        NSURL *target = [NSURL URLByResolvingAliasFileAtURL:url
                                                    options:(NSURLBookmarkResolutionWithoutUI |
                                                             NSURLBookmarkResolutionWithoutMounting)
                                                      error:nil];
        if (!target) {
            return nil;
        }
        url = target;
        resolved = YES;
        values = [url resourceValuesForKeys:keys error:nil];
        if (!values) {
            return nil;
        }
    }

    if (pIsDir) *pIsDir = [values[NSURLIsDirectoryKey] boolValue];
    return resolved ? [url path] : self;
}

- (NSString*)commonSuffixWithString:(NSString*)s {
    long a=[self length]-1;
    long b=[s length]-1;
    if (a < 0 || b < 0) return @"";
    while ([self characterAtIndex:a]==[s characterAtIndex:b] && a > 0 && b > 0) {
        a--;
        b--;
    }
    if (a==[self length]-1) return @"";
    else return [self substringFromIndex:a+1];
}

@end
