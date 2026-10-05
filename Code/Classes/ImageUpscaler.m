//
//  ImageUpscaler.m
//  JPEGDeux
//

#import "ImageUpscaler.h"
#import <CoreImage/CoreImage.h>

// Beyond this a Metal texture cannot hold the result.
static const CGFloat kMaxUpscaledDimension = 16384;
static const double kSharpness = 0.6;
static const double kSharpenRadius = 0.6;
static const NSUInteger kCacheSize = 2;

static CIContext *sharedContext(void) {
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGColorSpaceRef working = CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
        NSDictionary *options = @{
            kCIContextWorkingColorSpace: (__bridge id)working,
            kCIContextCacheIntermediates: @NO
        };
        // The default context renders on the GPU (Metal) when one is available.
        context = [CIContext contextWithOptions:options];
        CGColorSpaceRelease(working);
    });
    return context;
}

@interface UpscaleCacheEntry : NSObject
@property (nonatomic, strong) NSImage *source;
@property (nonatomic) NSSize pixelSize;
@property (nonatomic, strong) NSImage *result;
@end
@implementation UpscaleCacheEntry
@end

@implementation ImageUpscaler

+ (NSMutableArray<UpscaleCacheEntry *> *)cache {
    static NSMutableArray *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableArray array]; });
    return cache;
}

+ (NSImage *)upscaledImage:(NSImage *)image
                toFitSize:(NSSize)targetSize
              backingScale:(CGFloat)backingScale {
    if (!image || targetSize.width < 1 || targetSize.height < 1) return nil;
    if (backingScale < 1) backingScale = 1;

    NSSize target = NSMakeSize(round(targetSize.width * backingScale),
                               round(targetSize.height * backingScale));
    if (target.width < 1 || target.height < 1 ||
        target.width > kMaxUpscaledDimension || target.height > kMaxUpscaledDimension) return nil;

    // Only still bitmaps: the native size is that of the largest bitmap representation.
    NSBitmapImageRep *bitmap = nil;
    for (NSImageRep *rep in [image representations]) {
        if (![rep isKindOfClass:[NSBitmapImageRep class]]) continue;
        if (!bitmap || rep.pixelsWide > bitmap.pixelsWide) bitmap = (NSBitmapImageRep *)rep;
    }
    if (!bitmap || bitmap.pixelsWide < 1 || bitmap.pixelsHigh < 1) return nil;
    // Not enlarged: leave the normal path alone.
    if (target.width <= bitmap.pixelsWide && target.height <= bitmap.pixelsHigh) return nil;

    @synchronized (self) {
        NSMutableArray<UpscaleCacheEntry *> *cache = [self cache];
        for (UpscaleCacheEntry *entry in [cache copy]) {
            if (entry.source == image && NSEqualSizes(entry.pixelSize, target)) {
                [cache removeObject:entry];
                [cache insertObject:entry atIndex:0];
                return entry.result;
            }
        }
    }

    CGImageRef source = [bitmap CGImage];
    if (!source) return nil;

    CGColorSpaceRef sourceSpace = CGImageGetColorSpace(source);
    CGColorSpaceRef outSpace = NULL;
    if (sourceSpace && CGColorSpaceGetModel(sourceSpace) == kCGColorSpaceModelRGB) {
        outSpace = CGColorSpaceRetain(sourceSpace);
    } else {
        outSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    }

    const CGFloat width = (CGFloat)CGImageGetWidth(source);
    const CGFloat height = (CGFloat)CGImageGetHeight(source);
    CIImage *input = [CIImage imageWithCGImage:source];
    CIFilter *lanczos = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    [lanczos setValue:input forKey:kCIInputImageKey];
    [lanczos setValue:@(target.height / height) forKey:kCIInputScaleKey];
    [lanczos setValue:@((target.width / target.height) / (width / height)) forKey:kCIInputAspectRatioKey];
    CIImage *output = lanczos.outputImage;

    CIFilter *sharpen = [CIFilter filterWithName:@"CIUnsharpMask"];
    [sharpen setValue:output forKey:kCIInputImageKey];
    [sharpen setValue:@(MIN(6.0, MAX(1.5, kSharpenRadius * target.height / height))) forKey:kCIInputRadiusKey];
    [sharpen setValue:@(kSharpness) forKey:kCIInputIntensityKey];
    output = sharpen.outputImage;

    CGRect rect = CGRectMake(0, 0, target.width, target.height);
    CGImageRef scaled = output ? [sharedContext() createCGImage:output
                                                       fromRect:rect
                                                         format:kCIFormatRGBA8
                                                     colorSpace:outSpace] : NULL;
    CGColorSpaceRelease(outSpace);
    if (!scaled) return nil;

    NSImage *result = [[NSImage alloc] initWithCGImage:scaled size:targetSize];
    CGImageRelease(scaled);

    UpscaleCacheEntry *entry = [[UpscaleCacheEntry alloc] init];
    entry.source = image;
    entry.pixelSize = target;
    entry.result = result;
    @synchronized (self) {
        NSMutableArray<UpscaleCacheEntry *> *cache = [self cache];
        [cache insertObject:entry atIndex:0];
        while (cache.count > kCacheSize) [cache removeLastObject];
    }
    return result;
}

@end
