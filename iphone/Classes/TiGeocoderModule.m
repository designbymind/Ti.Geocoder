/**
 * Ti.Geocoder. Original wrapper Copyright (c) 2015 Benjamin Bahrenburg.
 * MapKit migration Copyright (c) 2026 DesignByMind LLC.
 */
#import "TiGeocoderModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "BXBGeocoderHelpers.h"
#import <math.h>

@implementation TiGeocoderModule
- (id)moduleGUID { return @"32bae808-920d-4d82-b99d-f0541f686692"; }
- (NSString *)moduleId { return @"ti.geocoder"; }

- (void)startup
{
    [super startup];
    _requests = [NSMutableDictionary dictionary];
}

- (void)shutdown:(id)sender
{
    ENSURE_UI_THREAD(shutdown, sender);
    _shuttingDown = YES;
    [_locationTimer invalidate];
    _locationTimer = nil;
    [self.locManager stopUpdatingLocation];
    self.locManager.delegate = nil;
    _placeCallback = nil;
    NSArray *pending = _requests.allValues;
    [_requests removeAllObjects];
    for (NSDictionary *entry in pending) {
        [entry[@"timer"] invalidate];
        [entry[@"request"] cancel];
    }
    [super shutdown:sender];
}

- (NSNumber *)isSupported:(id)args
{
    BOOL supported = [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){26, 0, 0}]
             && NSClassFromString(@"MKGeocodingRequest") != nil
             && NSClassFromString(@"MKReverseGeocodingRequest") != nil;
    return NUMBOOL(supported);
}

- (void)sendError:(NSString *)message code:(NSString *)code callback:(KrollCallback *)callback
{
    if (!callback || _shuttingDown) return;
    [self _fireEventToListener:@"completed" withObject:@{
        @"success": @NO, @"error": message ?: @"Geocoding failed.", @"code": code
    } listener:callback thisObject:nil];
}

// Main-thread request records retain native requests until completion/timeout.
// Removing a record before delivery guarantees a single callback, even if a
// cancelled request subsequently invokes its completion handler.
- (NSUUID *)trackRequest:(id)request callback:(KrollCallback *)callback
{
    NSUUID *token = [NSUUID UUID];
    __weak TiGeocoderModule *weakSelf = self;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:45 repeats:NO block:^(NSTimer *timer) {
        TiGeocoderModule *strongSelf = weakSelf;
        if (!strongSelf) return;
        NSDictionary *entry = strongSelf->_requests[token];
        if (!entry) return;
        [strongSelf->_requests removeObjectForKey:token];
        [entry[@"request"] cancel];
        [strongSelf sendError:@"Geocoding timed out." code:@"timeout" callback:entry[@"callback"]];
    }];
    _requests[token] = @{@"request": request, @"callback": callback, @"timer": timer};
    return token;
}

- (void)completeRequest:(NSUUID *)token mapItems:(NSArray<MKMapItem *> *)items error:(NSError *)error
{
    NSDictionary *entry = _requests[token];
    if (!entry || _shuttingDown) return;
    [_requests removeObjectForKey:token];
    [entry[@"timer"] invalidate];
    KrollCallback *callback = entry[@"callback"];
    if (error || items.count == 0) {
        [self sendError:error.localizedDescription ?: @"No places found."
                   code:error ? @"geocoding_failed" : @"no_results" callback:callback];
        return;
    }
    NSMutableArray *places = [NSMutableArray arrayWithCapacity:items.count];
    for (MKMapItem *item in items) [places addObject:[BXBGeocoderHelpers buildFromMapItem:item]];
    [self _fireEventToListener:@"completed" withObject:@{
        @"success": @YES, @"placeCount": @(places.count), @"places": places
    } listener:callback thisObject:nil];
}

- (void)forwardGeocoder:(id)args
{
    ENSURE_ARG_COUNT(args, 2);
    ENSURE_UI_THREAD(forwardGeocoder, args);
    KrollCallback *callback = args[1];
    ENSURE_TYPE(callback, KrollCallback);
    NSString *address = [[TiUtils stringValue:args[0]] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    MKGeocodingRequest *request = address.length ? [[MKGeocodingRequest alloc] initWithAddressString:address] : nil;
    if (!request) {
        [self sendError:@"A nonempty address is required." code:@"invalid_address" callback:callback];
        return;
    }
    NSUUID *token = [self trackRequest:request callback:callback];
    __weak TiGeocoderModule *weakSelf = self;
    [request getMapItemsWithCompletionHandler:^(NSArray<MKMapItem *> *items, NSError *error) {
        [weakSelf completeRequest:token mapItems:items error:error];
    }];
}

- (void)reverseGeocoder:(id)args
{
    ENSURE_ARG_COUNT(args, 3);
    ENSURE_UI_THREAD(reverseGeocoder, args);
    KrollCallback *callback = args[2];
    ENSURE_TYPE(callback, KrollCallback);
    double latitude = [TiUtils doubleValue:args[0] def:NAN];
    double longitude = [TiUtils doubleValue:args[1] def:NAN];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    if (!isfinite(latitude) || !isfinite(longitude) || !CLLocationCoordinate2DIsValid(coordinate)) {
        [self sendError:@"Latitude/longitude must be finite and within valid ranges." code:@"invalid_coordinates" callback:callback];
        return;
    }
    [self findPlace:[[CLLocation alloc] initWithLatitude:latitude longitude:longitude] callback:callback];
}

- (void)findPlace:(CLLocation *)location callback:(KrollCallback *)callback
{
    MKReverseGeocodingRequest *request = [[MKReverseGeocodingRequest alloc] initWithLocation:location];
    if (!request) {
        [self sendError:@"Invalid location." code:@"invalid_coordinates" callback:callback];
        return;
    }
    NSUUID *token = [self trackRequest:request callback:callback];
    __weak TiGeocoderModule *weakSelf = self;
    [request getMapItemsWithCompletionHandler:^(NSArray<MKMapItem *> *items, NSError *error) {
        [weakSelf completeRequest:token mapItems:items error:error];
    }];
}

- (void)getCurrentPlace:(id)callback
{
    ENSURE_SINGLE_ARG(callback, KrollCallback);
    ENSURE_UI_THREAD(getCurrentPlace, callback);
    if (_placeCallback) {
        [self sendError:@"A current-place request is already pending." code:@"busy" callback:callback];
        return;
    }
    if (![CLLocationManager locationServicesEnabled]) {
        [self sendError:@"Location Services are disabled." code:@"location_disabled" callback:callback];
        return;
    }
    if (!self.locManager) {
        self.locManager = [[CLLocationManager alloc] init];
        self.locManager.delegate = self;
        self.locManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    _staleLimit = [TiUtils doubleValue:[self valueForUndefinedKey:@"staleLimit"] def:15.0];
    if (!isfinite(_staleLimit) || _staleLimit <= 0) _staleLimit = 15.0;
    _placeCallback = callback;
    __weak TiGeocoderModule *weakSelf = self;
    _locationTimer = [NSTimer scheduledTimerWithTimeInterval:60 repeats:NO block:^(NSTimer *timer) {
        [weakSelf finishLocationWithError:@"Current location timed out." code:@"timeout"];
    }];
    [self updateLocationAuthorization];
}

- (void)updateLocationAuthorization
{
    if (!_placeCallback) return;
    switch (self.locManager.authorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
            if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
                [self finishLocationWithError:@"getCurrentPlace requires NSLocationWhenInUseUsageDescription." code:@"missing_usage_description"];
                return;
            }
            [self.locManager requestWhenInUseAuthorization];
            break;
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            [self finishLocationWithError:@"Location permission was denied or restricted." code:@"permission_denied"];
            break;
        default:
            if (!_isStarted) {
                _isStarted = YES;
                [self.locManager startUpdatingLocation];
            }
            break;
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    [self updateLocationAuthorization];
}

- (void)finishLocationWithError:(NSString *)message code:(NSString *)code
{
    KrollCallback *callback = _placeCallback;
    _placeCallback = nil;
    _isStarted = NO;
    [_locationTimer invalidate];
    _locationTimer = nil;
    [self.locManager stopUpdatingLocation];
    [self sendError:message code:code callback:callback];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if (error.code == kCLErrorLocationUnknown) return; // transient; bounded by our timer
    [self finishLocationWithError:error.localizedDescription code:@"location_failed"];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (!_placeCallback) return;
    CLLocation *location = locations.lastObject;
    if (!location || location.horizontalAccuracy < 0 ||
        !CLLocationCoordinate2DIsValid(location.coordinate) ||
        fabs(location.timestamp.timeIntervalSinceNow) > _staleLimit) return;
    KrollCallback *callback = _placeCallback;
    _placeCallback = nil;
    _isStarted = NO;
    [_locationTimer invalidate];
    _locationTimer = nil;
    [manager stopUpdatingLocation];
    [self findPlace:location callback:callback];
}
@end
