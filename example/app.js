// Ti.Geocoder iOS 3.0.0 — iOS 26+ and Titanium SDK 13.4.1.GA+.
const geocoder = require('ti.geocoder');
const win = Ti.UI.createWindow({ backgroundColor: '#FFFFFF' });
const output = Ti.UI.createTextArea({ top: 170, left: 16, right: 16, bottom: 20, editable: false });
const forward = Ti.UI.createButton({ title: 'Geocode Williamsburg', top: 60, height: 40 });
const current = Ti.UI.createButton({ title: 'Find current place', top: 110, height: 40 });
function completed(e) {
    output.value = JSON.stringify(e, null, 2);
    Ti.API.info(output.value);
    if (e.success) {
        e.places.forEach(function (place) {
            Ti.API.info(JSON.stringify({ locality: place.locality, subLocality: place.subLocality,
                subAdministrativeArea: place.subAdministrativeArea }));
        });
    }
}
forward.addEventListener('click', function () {
    geocoder.forwardGeocoder('Williamsburg, Brooklyn, New York', completed);
});
// Only current-place acquisition needs NSLocationWhenInUseUsageDescription.
current.addEventListener('click', function () { geocoder.getCurrentPlace(completed); });
win.add(forward); win.add(current); win.add(output); win.open();
// Supplied coordinates also work without device-location permission:
// geocoder.reverseGeocoder(40.7178, -73.9580, completed);
