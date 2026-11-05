#import "HBTheme.h"
UIColor *HBColorFromHex(NSString *hex) {
    unsigned value = 0; if (hex.length == 7) [[NSScanner scannerWithString:[hex substringFromIndex:1]] scanHexInt:&value];
    return [UIColor colorWithRed:((value >> 16) & 255) / 255.0 green:((value >> 8) & 255) / 255.0 blue:(value & 255) / 255.0 alpha:1];
}
NSString *HBHexFromColor(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0; [color getRed:&r green:&g blue:&b alpha:nil];
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)lround(MAX(0, MIN(1, r)) * 255), (int)lround(MAX(0, MIN(1, g)) * 255), (int)lround(MAX(0, MIN(1, b)) * 255)];
}
static double Linear(double n) { return n <= 0.04045 ? n / 12.92 : pow((n + 0.055) / 1.055, 2.4); }
UIColor *HBContrastingInk(UIColor *background) {
    CGFloat r = 0, g = 0, b = 0; [background getRed:&r green:&g blue:&b alpha:nil];
    double light = 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b);
    return light > 0.179 ? UIColor.blackColor : UIColor.whiteColor;
}
