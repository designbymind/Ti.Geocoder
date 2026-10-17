# Ti.Geocoder 3.0.0 validation

Tested October 16, 2026 (America/Los_Angeles). DateMaps was not modified.

## Source and package

- Authoritative upstream: https://github.com/designbymind/Ti.Geocoder.git
- Starting commit: `a53b334` on `master`; local branch: `mapkit-ios26-3.0.0`.
- The old non-Git workspace copy is preserved separately at
  `../Development Backups/Ti.Geocoder-local-20261016/`.
- Titanium SDK: 13.4.1.GA. Compiler: Xcode 27.1 Beta, iOS SDK 27.1.
- Native deployment minimum: iOS 26.0 (verified in Mach-O `LC_BUILD_VERSION`).
- Module builds and XCFramework packaging passed.
- Device library: arm64. Simulator library: arm64 + x86_64 (`lipo` verified).
- ZIP integrity and embedded 3.0.0 manifest passed. Packaged documentation and example use MapKit.
- Binary references `MKGeocodingRequest` and `MKReverseGeocodingRequest`, with no `CLGeocoder` reference.
- Package: `iphone/dist/ti.geocoder-iphone-3.0.0.zip`.
- SHA-256: `11985e631b42b8bf2cc9cdd7ed9051d151ecb292f183e55526329a7fb0d116ba`.
- Classic example and validation JavaScript passed `node --check`; Git whitespace checks passed.

## Real Titanium bridge and Apple service checks

An isolated Classic Titanium app was compiled, installed, and launched on the
**iOS 27.0 iPhone 18 Pro simulator**. These checks use the packaged native binary
and Apple's actual MapKit services, not native stand-ins or network mocks.
The test app was cleaned and rebuilt after the final module binary changed.

| Run | Checks | Failures |
| --- | ---: | ---: |
| iOS 27.0.0, location denied | 41 | 0 |
| iOS 27.0.0, location granted | 45 | 0 |

Verified:

- `require('ti.geocoder')`, `isSupported()` returning a JavaScript boolean.
- Blank/whitespace address, out-of-range latitude, and nonfinite longitude failures.
- Two concurrent forward geocodes deliver independent callbacks.
- Existing success/failure callback shapes, valid coordinates, and no duplicate
  callbacks within the suite and its three-second final observation window.
- Manhattan, Cupertino, Williamsburg, Brooklyn, London, and Paris geocoding.
- Forward and supplied-coordinate reverse geocoding work with location permission denied.
- Denied `getCurrentPlace()` returns an error callback.
- Granted `getCurrentPlace()` returns a geocoded simulated location.
- A second overlapping location acquisition returns `busy` while the original completes.

Raw responses and assertions are in `results/ios-27.0.0-denied.json` and
`results/ios-27.0.0-granted.json`. The simulator location used for the granted run
was the public coordinate `40.7178, -73.9580` in Williamsburg, Brooklyn.

| Lookup | locality | subLocality | subAdministrativeArea |
| --- | --- | --- | --- |
| Williamsburg forward | New York | Brooklyn | Kings County |
| Brooklyn reverse | New York | Brooklyn | Kings County |
| Current place (simulated Brooklyn) | New York | Brooklyn | Kings County |
| London forward | London | City of Westminster | London |
| Paris reverse | Paris | 7th Arr. | Paris |

For Williamsburg, Apple's `name` is `Williamsburg` while `subLocality` is
`Brooklyn`. This is Apple's actual classification. No neighborhood, county, or
city value is synthesized by parsing a formatted address.

## Compatibility decision and remaining validation

Requests use the new MapKit APIs. Structured address serialization deliberately
retains the deprecated public `MKMapItem.placemark` accessor (and legacy address
dictionary where present), because the new address types do not directly expose
neighborhood/county fields. Deprecation warnings are isolated to that serializer.
The successful checks above confirm current data availability for these samples;
they do not guarantee that Apple supplies each component for every place.

**iOS 26.5 runtime validation is incomplete.** The existing iPhone 17 Pro
simulator stalled during app/permission operations, including a 60-second
`simctl privacy ... revoke location` timeout. It subsequently reported Shutdown.
A restart and fresh validation-simulator attempt did not yield a usable test
session. Logs are retained locally under `validation/logs/`. No passing iOS 26.5
runtime result is claimed. The native binary's iOS 26.0 minimum and API
availability were checked separately.

Physical iOS 26+ device testing, a fresh system permission prompt, location
services disabled at the system level, artificial network timeouts, service
throttling, stale-location filtering, and pending-request shutdown remain
unverified. x86_64 simulator code compiled but was not executed on this arm64 Mac.
Android source was not changed or tested.

The package is installed only in the isolated validation app. It is not globally
installed, uploaded, tagged, or released. DateMaps integration is deferred until
module testing has been reviewed with the user.
