#import <Foundation/Foundation.h>
@import ZXingObjC;

/// The ZXingObj framework encoder throws exceptions, which Swift is not
/// built to handle, so this class wraps the encoding function.
@interface NYPLZXingEncoder : NSObject

+ (UIImage *)encodeWithString:(NSString *)string
                       format:(ZXBarcodeFormat)format
                        width:(int)width
                       height:(int)height
                  encodeHints:(ZXEncodeHints *)hints;

@end
