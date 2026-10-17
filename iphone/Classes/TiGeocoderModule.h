// Ti.Geocoder — native MapKit geocoding for Titanium.
#import "TiModule.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface TiGeocoderModule : TiModule <CLLocationManagerDelegate> {
    KrollCallback *_placeCallback;
    NSMutableDictionary<NSUUID *, NSDictionary *> *_requests;
    NSTimer *_locationTimer;
    BOOL _isStarted;
    BOOL _shuttingDown;
    NSTimeInterval _staleLimit;
}
@property (nonatomic, strong) CLLocationManager *locManager;
@end
