//
//  PreviewImageView.m
//  JPEGDeux 2
//
//  Created by peter on Thu Jul 11 2002.
//  This code is released under the Modified BSD license
//

#import "PreviewImageView.h"

@implementation PreviewImageView

- (void)setColor:(NSColor*)color {
    [super setColor:color];
    // Trigger a redraw to update the background color
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    // Call parent to draw the image
    [super drawRect:rect];

    // Draw background areas based on scaling mode
    NSRect bounds = [self bounds];
    NSRect imageRect = {NSMakePoint(0, 0), [myImage size]};

    [myBackgroundColor set];
    if (!myImage) {
        NSRectFill(bounds);
    }
    else {
        switch (myScaling) {
            case ScaleDownToFit:
                if (!(NSHeight(imageRect) < NSHeight(bounds) || NSWidth(imageRect) < NSWidth(bounds)))
                    goto LabelScaleNone;
                //note the fall through
            case ScaleToFit:
                break;

                LabelScaleNone:
            case ScaleNone: {
                float xSpace=(NSWidth(bounds) - NSWidth(imageRect))/2.0;
                float ySpace=(NSHeight(bounds) - NSHeight(imageRect))/2.0;
                if (xSpace < 0 && ySpace >= 0) { //space on bottom and top, not sides
                    NSRectFill(NSMakeRect(0, 0, NSWidth(bounds), ySpace));
                    NSRectFill(NSMakeRect(0, NSHeight(bounds)-ySpace, NSWidth(bounds), ySpace));
                }
                else if (xSpace >= 0 && ySpace < 0) { //space on sides, not bottom and top
                    NSRectFill(NSMakeRect(0, 0, xSpace, NSHeight(bounds)));
                    NSRectFill(NSMakeRect(NSWidth(bounds)-xSpace, 0, xSpace, NSHeight(bounds)));
                }
                else if (xSpace > 0 && ySpace > 0) { //image is too small all around
                    NSRectFill(NSMakeRect(0, 0, NSWidth(bounds), ySpace+1)); //bottom, we add 1 because of ugly round off otherwise
                    NSRectFill(NSMakeRect(0, NSHeight(bounds)-ySpace, NSWidth(bounds), ySpace)); //top
                    NSRectFill(NSMakeRect(0, ySpace, xSpace+1, .5f+NSHeight(bounds)-2.0f*ySpace)); //left
                    NSRectFill(NSMakeRect(NSWidth(bounds)-xSpace, ySpace, xSpace, .5f+NSHeight(bounds)-2.0f*ySpace)); //right
                }
                break;
            }
            case ScaleDownProportionally:
                if (NSHeight(imageRect) < NSHeight(bounds) && NSWidth(imageRect) < NSWidth(bounds)) goto LabelScaleNone;
                //note the fall through
            case ScaleProportionally:
                if (NSHeight(imageRect)*NSWidth(bounds) > NSHeight(bounds)*NSWidth(imageRect)) {
                    //image is tall
                    float scalingFactor=NSHeight(bounds)/NSHeight(imageRect);
                    NSRect drawingRect=NSInsetRect(bounds, (NSWidth(bounds)-NSWidth(imageRect)*scalingFactor)/2.0, 0);
                    NSRectFill(NSMakeRect(0, 0, NSMinX(drawingRect), NSHeight(bounds)));
                    NSRectFill(NSMakeRect(NSMaxX(drawingRect), 0, NSMaxX(bounds)-NSMaxX(drawingRect), NSHeight(bounds)));
                }
                else {
                    //image is wide
                    NSRect drawingRect;
                    float scalingFactor=NSWidth(bounds)/NSWidth(imageRect);
                    drawingRect=NSInsetRect(bounds, 0, (NSHeight(bounds)-NSHeight(imageRect)*scalingFactor)/2.0);
                    NSRectFill(NSMakeRect(0, NSMaxY(drawingRect), NSWidth(bounds), NSMaxY(bounds)-NSMaxY(drawingRect)));
                    NSRectFill(NSMakeRect(0, 0, NSWidth(bounds), NSMinY(drawingRect)));
                }
                break;
            default: ; //this ought to shut gcc up
        }
    }
}

@end
