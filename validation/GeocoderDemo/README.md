# Isolated Titanium integration app

This app tests the packaged `ti.geocoder` 3.0.0 binary through real JavaScript calls
and real Apple MapKit services. It does not use mocks or modify DateMaps.

From the repository root, extract the module ZIP into this app directory (the ZIP
creates its `modules/iphone/ti.geocoder/3.0.0/` tree), then build:

```sh
unzip -o iphone/dist/ti.geocoder-iphone-3.0.0.zip -d validation/GeocoderDemo
DEVELOPER_DIR=/Applications/Xcode-27.1-Beta.app/Contents/Developer \
ti build -p ios -T simulator --build-only --sdk 13.4.1.GA \
  --project-dir "$PWD/validation/GeocoderDemo" -C SIMULATOR_UDID --no-prompt
```

Use an iOS 26+ simulator. Boot it and wait for `xcrun simctl bootstatus UDID -b`
first. If rebuilding the same version, clean this test app before building again.

Run both permission modes against the built app:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1-Beta.app/Contents/Developer \
python3 validation/run-tests.py --device SIMULATOR_UDID \
  --app validation/GeocoderDemo/build/iphone/build/Products/Debug-iphonesimulator/GeocoderDemo.app
```

The runner installs only into the selected simulator and changes location
permission only for `com.designbymind.geocoderdemo`. For the granted test, it sets
that simulator's simulated location to a public Williamsburg coordinate. Clear
that location with `xcrun simctl location UDID clear` afterward if desired.
No global Titanium module installation is performed.

Raw callbacks and assertions are saved under `validation/results/`. Each run
checks support detection, invalid inputs, simultaneous independent forward
requests, forward and reverse results in the US/UK/France, and current-place
permission handling. Williamsburg/Brooklyn tests require nonempty `locality`,
`subLocality`, and `subAdministrativeArea`; other regions record components without
assuming every geographic subdivision exists everywhere. The granted run also
checks overlapping current-location requests return `busy` without displacing
the first callback. Callbacks are observed for three seconds after the suite to
catch immediate duplicate delivery. Network timeouts, service throttling, a fresh
system permission prompt, and physical-device behavior need separate testing.
