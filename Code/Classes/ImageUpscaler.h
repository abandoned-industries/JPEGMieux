//
//  ImageUpscaler.h
//  JPEGDeux
//
//  Enlarges stills that are shown bigger than their native size, using
//  Lanczos resampling on the GPU plus a light sharpen.
//

#import <Cocoa/Cocoa.h>

@interface ImageUpscaler : NSObject

// Returns a version of the image whose pixels match the target, or nil when the
// image is not being enlarged (or cannot be upscaled) and should be shown as is.
// targetSize is the size on screen in points; the result's NSImage size is
// targetSize, so showing it at that size needs no further resampling.
// Results are cached per image and target pixel size.
+ (NSImage *)upscaledImage:(NSImage *)image
                toFitSize:(NSSize)targetSize
              backingScale:(CGFloat)backingScale;

@end
