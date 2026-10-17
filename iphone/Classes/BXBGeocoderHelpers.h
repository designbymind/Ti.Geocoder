#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface BXBGeocoderHelpers : NSObject
+ (NSDictionary *)buildFromMapItem:(MKMapItem *)item;
@end
