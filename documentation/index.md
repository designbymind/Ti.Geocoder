# Ti.Geocoder

Native geocoding for Titanium. The iOS **3.0.0** module uses MapKit's
`MKGeocodingRequest` and `MKReverseGeocodingRequest` and requires **iOS 26.0+**
and **Titanium SDK 13.4.1.GA+**. Android is unchanged by this migration.

## iOS setup

Install `iphone/dist/ti.geocoder-iphone-3.0.0.zip` using your usual Titanium
module installation workflow, then pin the version in `tiapp.xml`:

```xml
<modules>
    <module platform="iphone" version="3.0.0">ti.geocoder</module>
</modules>
<ios>
    <min-ios-ver>26.0</min-ios-ver>
    <plist>
        <dict>
            <key>NSLocationWhenInUseUsageDescription</key>
            <string>Use your location to find your current place.</string>
        </dict>
    </plist>
</ios>
```

The usage description is required only for `getCurrentPlace()`. Forward geocoding
and reverse geocoding of supplied coordinates do not request location permission.
Geocoding needs network access and is subject to Apple's service limits.

## JavaScript API

The existing method names and argument order are preserved:

```js
const geocoder = require('ti.geocoder');
Ti.API.info('Supported: ' + geocoder.isSupported());

function completed(e) {
    if (!e.success) {
        Ti.API.error(e.error);
        return;
    }
    e.places.forEach(function (place) {
        Ti.API.info(JSON.stringify({
            latitude: place.latitude,
            longitude: place.longitude,
            locality: place.locality,
            subLocality: place.subLocality,
            subAdministrativeArea: place.subAdministrativeArea
        }));
    });
}
geocoder.forwardGeocoder('Williamsburg, Brooklyn, New York', completed);
geocoder.reverseGeocoder(40.7178, -73.9580, completed);
// Call separately when the user asks for their current place:
// geocoder.getCurrentPlace(completed);
```

- `isSupported()` returns a boolean indicating availability of the iOS 26 MapKit requests.
- `forwardGeocoder(address, callback)` resolves an address to one or more places.
- `reverseGeocoder(latitude, longitude, callback)` resolves coordinates to places.
- `getCurrentPlace(callback)` requests foreground location permission when needed,
  obtains a fresh device position, and reverse geocodes it. A second overlapping
  location acquisition returns `success: false, code: 'busy'`; it does not replace
  the first callback. The existing `staleLimit` property controls the maximum
  accepted location age in seconds (default 15; nonpositive/nonfinite values use
  the default). The obsolete `purpose` property is no longer used: supply the
  Info.plist usage description instead. Background location is not enabled.

Success callbacks retain `{ success: true, placeCount: Number, places: Array }`.
Failures retain `{ success: false, error: String }` and add a `code` string:
`invalid_address`, `invalid_coordinates`, `no_results`, `geocoding_failed`,
`timeout`, `busy`, `location_disabled`, `permission_denied`,
`missing_usage_description`, or `location_failed`.

Empty/whitespace addresses and invalid/nonfinite coordinates return failures.
MapKit requests time out after 45 seconds. Location acquisition (including waiting
for permission) times out after 60 seconds; reverse geocoding then has its own
45-second bound. Permission failures are delivered through the callback without
presenting an extra native alert. Independent geocoding requests retain their own
callback and can run concurrently. Avoid issuing a request on every keystroke.

## Address-component compatibility

Each place retains `latitude`, `longitude`, and a millisecond `timestamp`.
When supplied by Apple it also contains:

| Field | Meaning |
| --- | --- |
| `locality` | City/locality |
| `subLocality` | Sub-locality, district, borough, or neighborhood as classified by Apple |
| `subAdministrativeArea` | County or equivalent administrative subdivision |
| `administrativeArea` | State/province |
| `countryCode`, `countryName` | Country |
| `postalCode` | Postal code |
| `thoroughfare`, `subThoroughfare` | Street and street number |
| `addressDictionary` | Legacy address dictionary, when present |
| `region` | Legacy circular region (`lat`, `lng`, `radius`, `identifier`), when present |
| `name`, `fullAddress`, `shortAddress` | Additional MapKit descriptions |

**Structured components require a deliberate compatibility accessor.** iOS 26's
`MKAddress` and `MKAddressRepresentations` expose formatted addresses and city and
country information, but no direct neighborhood/county fields. Requests use the
new MapKit APIs exclusively; serialization still reads the public, deprecated
`MKMapItem.placemark` accessor to preserve these important fields. Its deprecation
warning is isolated to that serializer. No `CLGeocoder` requests remain.

No address components are inferred by splitting formatted strings. Missing fields
are omitted, as before. A city/state is never substituted for a missing
neighborhood/county. Apple's coverage and geographic classifications vary, and
`subLocality` is not guaranteed to be a recognizable neighborhood (for example,
Apple may return a borough). Consumers must handle missing values. This remains a
compatibility compromise rather than a completely deprecation-free migration.

## Development and validation

The upstream iOS source directory remains `iphone/`.

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1-Beta.app/Contents/Developer \
ti build -p ios --build-only --project-dir "$PWD/iphone" \
  --sdk 13.4.1.GA --no-prompt --no-banner
```

See `validation/RESULTS.md` for actual checks and limitations, and
`validation/GeocoderDemo` for the isolated Titanium integration app. The app stores
raw callbacks and assertions in its Documents `results.json`; see its README for
running permission-denied and permission-granted checks.

This change does not modify DateMaps, globally install the module, or publish a
GitHub release. The existing Android implementation and distribution are retained.
