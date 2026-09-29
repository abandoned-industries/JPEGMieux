//
//  ImageLoader.m
//  JPEGDeux
//
//  Efficient image loading with thumbnail support and async loading
//

#import "ImageLoader.h"
#import <ImageIO/ImageIO.h>

// Shared queue for background image loading
static dispatch_queue_t imageLoadingQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.jpegdeux.imageloading", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

// Global setting for skipping iCloud files (default YES)
static BOOL sSkipICloudFiles = YES;

@implementation ImageLoader

+ (void)setSkipICloudFiles:(BOOL)skip {
    sSkipICloudFiles = skip;
}

+ (BOOL)skipICloudFiles {
    return sSkipICloudFiles;
}

// Create a placeholder image for files not yet downloaded from iCloud
+ (NSImage *)iCloudPlaceholderImageWithFilename:(NSString *)filename {
    NSSize size = NSMakeSize(800, 600);

    NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        // Dark background
        [[NSColor colorWithWhite:0.15 alpha:1.0] set];
        NSRectFill(NSMakeRect(0, 0, size.width, size.height));

        // Draw iCloud icon (simple cloud shape using text)
        NSMutableParagraphStyle *centerStyle = [[NSMutableParagraphStyle alloc] init];
        [centerStyle setAlignment:NSTextAlignmentCenter];

        // Cloud emoji as icon
        NSDictionary *iconAttrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:72],
            NSForegroundColorAttributeName: [NSColor colorWithWhite:0.5 alpha:1.0],
            NSParagraphStyleAttributeName: centerStyle
        };
        [@"\u2601" drawInRect:NSMakeRect(0, size.height/2 + 20, size.width, 100) withAttributes:iconAttrs];

        // "Not Downloaded" text
        NSDictionary *titleAttrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:24 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor colorWithWhite:0.7 alpha:1.0],
            NSParagraphStyleAttributeName: centerStyle
        };
        [@"iCloud File Not Downloaded" drawInRect:NSMakeRect(0, size.height/2 - 30, size.width, 40) withAttributes:titleAttrs];

        // Filename
        NSDictionary *filenameAttrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:14],
            NSForegroundColorAttributeName: [NSColor colorWithWhite:0.5 alpha:1.0],
            NSParagraphStyleAttributeName: centerStyle
        };
        NSString *displayName = [filename lastPathComponent] ?: @"Unknown";
        [displayName drawInRect:NSMakeRect(20, size.height/2 - 70, size.width - 40, 30) withAttributes:filenameAttrs];

        return YES;
    }];

    return image;
}

// Check if file is available locally (not an iCloud placeholder waiting to download)
+ (BOOL)isFileDownloaded:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    if (!url) return NO;

    NSString *downloadStatus = nil;
    NSError *error = nil;
    [url getResourceValue:&downloadStatus forKey:NSURLUbiquitousItemDownloadingStatusKey error:&error];

    // If not an iCloud file, downloadStatus will be nil - that's fine
    if (!downloadStatus) return YES;

    // Check if fully downloaded
    return [downloadStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent];
}

+ (NSImage *)thumbnailForPath:(NSString *)path maxSize:(CGFloat)maxSize {
    if (!path) return nil;

    // Skip iCloud files that aren't downloaded yet
    if (![self isFileDownloaded:path]) {
        return nil;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    if (!url) return nil;

    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) return nil;

    // Options for thumbnail generation
    NSDictionary *options = @{
        (id)kCGImageSourceThumbnailMaxPixelSize: @(maxSize),
        (id)kCGImageSourceCreateThumbnailFromImageIfAbsent: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,  // Apply orientation
        (id)kCGImageSourceShouldCacheImmediately: @YES
    };

    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);

    if (!thumbnail) return nil;

    NSImage *image = [[NSImage alloc] initWithCGImage:thumbnail size:NSZeroSize];
    CGImageRelease(thumbnail);

    return image;
}

+ (void)thumbnailForPath:(NSString *)path
                 maxSize:(CGFloat)maxSize
              completion:(void (^)(NSImage *thumbnail))completion {
    if (!completion) return;

    dispatch_async(imageLoadingQueue(), ^{
        NSImage *thumbnail = [self thumbnailForPath:path maxSize:maxSize];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(thumbnail);
        });
    });
}

+ (void)imageForPath:(NSString *)path
          completion:(void (^)(NSImage *image))completion {
    if (!completion) return;

    dispatch_async(imageLoadingQueue(), ^{
        NSImage *image = [self imageForPath:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    });
}

+ (NSImage *)imageForPath:(NSString *)path {
    if (!path) return nil;

    // Check if it's a URL or file path
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        NSURL *url = [NSURL URLWithString:path];
        if (!url) return nil;
        return [[NSImage alloc] initWithContentsOfURL:url];
    }

    // Handle iCloud files that aren't downloaded yet
    if (![self isFileDownloaded:path]) {
        if (sSkipICloudFiles) {
            return nil;  // Skip - will advance to next image
        } else {
            return [self iCloudPlaceholderImageWithFilename:path];  // Show placeholder
        }
    }

    // Use NSImage directly - it handles edge cases better than CGImageSource
    return [[NSImage alloc] initWithContentsOfFile:path];
}

+ (NSSize)imageSizeForPath:(NSString *)path {
    if (!path) return NSZeroSize;

    // Skip iCloud files that aren't downloaded yet
    if (![self isFileDownloaded:path]) {
        return NSZeroSize;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    if (!url) return NSZeroSize;

    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) return NSZeroSize;

    NSDictionary *properties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    CFRelease(source);

    if (!properties) return NSZeroSize;

    NSNumber *width = properties[(id)kCGImagePropertyPixelWidth];
    NSNumber *height = properties[(id)kCGImagePropertyPixelHeight];

    if (!width || !height) return NSZeroSize;

    // Check for orientation that swaps width/height
    NSNumber *orientation = properties[(id)kCGImagePropertyOrientation];
    if (orientation) {
        int orient = [orientation intValue];
        // Orientations 5-8 swap width and height
        if (orient >= 5 && orient <= 8) {
            return NSMakeSize([height floatValue], [width floatValue]);
        }
    }

    return NSMakeSize([width floatValue], [height floatValue]);
}

@end
