/**
 * Ti.Geocoder. Original wrapper Copyright (c) 2015 Benjamin Bahrenburg.
 * MapKit migration Copyright (c) 2026 DesignByMind LLC.
 */
#import "BXBGeocoderHelpers.h"

@implementation BXBGeocoderHelpers
+ (NSDictionary *)buildFromMapItem:(MKMapItem *)item
{
    CLLocation *location = item.location;
    NSMutableDictionary *data = [@{
        @"latitude": @(location.coordinate.latitude),
        @"longitude": @(location.coordinate.longitude),
        @"timestamp": @((long long)(location.timestamp.timeIntervalSince1970 * 1000))
    } mutableCopy];
    if (item.name) data[@"name"] = item.name;
    if (item.address.fullAddress) data[@"fullAddress"] = item.address.fullAddress;
    if (item.address.shortAddress) data[@"shortAddress"] = item.address.shortAddress;

    // MapKit's iOS 26 address types do not expose neighborhood or county.
    // Keep the public placemark accessor solely for structured-data compatibility.
    // Never parse a formatted address or substitute city/state for these fields.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    MKPlacemark *placemark = item.placemark;
    NSDictionary *components = @{
        @"countryCode": placemark.ISOcountryCode ?: @"",
        @"countryName": placemark.country ?: @"",
        @"postalCode": placemark.postalCode ?: @"",
        @"administrativeArea": placemark.administrativeArea ?: @"",
        @"subAdministrativeArea": placemark.subAdministrativeArea ?: @"",
        @"locality": placemark.locality ?: @"",
        @"subLocality": placemark.subLocality ?: @"",
        @"thoroughfare": placemark.thoroughfare ?: @"",
        @"subThoroughfare": placemark.subThoroughfare ?: @""
    };
    [components enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if (value.length > 0) data[key] = value;
    }];
    // Preserve the original dictionary verbatim when Apple supplies it.
    if (placemark.addressDictionary) data[@"addressDictionary"] = placemark.addressDictionary;
    CLRegion *region = placemark.region;
    if ([region isKindOfClass:[CLCircularRegion class]]) {
        CLCircularRegion *circle = (CLCircularRegion *)region;
        data[@"region"] = @{@"lat": @(circle.center.latitude), @"lng": @(circle.center.longitude),
                            @"radius": @(circle.radius), @"identifier": circle.identifier ?: @""};
    }
#pragma clang diagnostic pop
    // Only use direct, semantically equivalent MapKit fields as fallbacks.
    if (!data[@"locality"] && item.addressRepresentations.cityName.length) {
        data[@"locality"] = item.addressRepresentations.cityName;
    }
    if (!data[@"countryCode"] && item.addressRepresentations.regionCode.length) {
        data[@"countryCode"] = item.addressRepresentations.regionCode;
    }
    if (!data[@"countryName"] && item.addressRepresentations.regionName.length) {
        data[@"countryName"] = item.addressRepresentations.regionName;
    }
    return data;
}
@end
