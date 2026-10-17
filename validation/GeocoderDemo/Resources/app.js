/* Isolated integration checks for the real Titanium -> Objective-C -> MapKit path. */
const geocoder = require('ti.geocoder');
const resultFile = Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'results.json');
const modeFile = Ti.Filesystem.getFile(Ti.Filesystem.applicationDataDirectory, 'mode.txt');
const mode = modeFile.exists() ? modeFile.read().text.trim() : 'denied';
const report = { version: '3.0.0', os: Ti.Platform.version, mode: mode, checks: [], responses: {}, complete: false };
const win = Ti.UI.createWindow({ backgroundColor: '#F2F4F8' });
const title = Ti.UI.createLabel({ text: 'Ti.Geocoder 3.0.0', top: 64, color: '#18243A', font: { fontSize: 25, fontWeight: 'bold' } });
const output = Ti.UI.createTextArea({ top: 110, bottom: 35, left: 16, right: 16, editable: false,
    color: '#18243A', backgroundColor: '#FFFFFF', font: { fontSize: 13 }, value: '' });
win.add(title); win.add(output);
function save() { resultFile.write(JSON.stringify(report, null, 2)); }
function check(ok, name, detail) {
    const record = { ok: Boolean(ok), name: name, detail: detail || null };
    report.checks.push(record);
    const line = (ok ? 'PASS ' : 'FAIL ') + name;
    output.value += line + '\n';
    Ti.API.info('[GeocoderCheck] ' + line + ' ' + JSON.stringify(detail || {}));
    save();
}
function request(name, invoke, expectSuccess, validate) {
    return new Promise(function (resolve) {
        let calls = 0;
        const watchdog = setTimeout(function () {
            if (calls === 0) { check(false, name + ' callback deadline'); resolve(); }
        }, 65000);
        invoke(function (e) {
            calls++;
            check(calls === 1, name + ' callback once');
            if (calls !== 1) return;
            clearTimeout(watchdog);
            report.responses[name] = e;
            check(e.success === expectSuccess, name + ' success flag', e.success ? { placeCount: e.placeCount } : e);
            if (expectSuccess && e.success) {
                check(Array.isArray(e.places) && e.placeCount === e.places.length && e.placeCount > 0,
                    name + ' callback structure');
                check(e.places.every(function (p) { return Number.isFinite(p.latitude) && Number.isFinite(p.longitude); }),
                    name + ' coordinates');
            }
            if (validate) validate(e);
            save(); resolve(e);
        });
    });
}
async function run() {
    check(geocoder.isSupported() === true, 'isSupported');
    await request('blank address', function (cb) { geocoder.forwardGeocoder('  ', cb); }, false,
        function (e) { check(e.code === 'invalid_address' && typeof e.error === 'string', 'blank error payload'); });
    await request('invalid latitude', function (cb) { geocoder.reverseGeocoder(91, 0, cb); }, false);
    await request('NaN longitude', function (cb) { geocoder.reverseGeocoder(0, NaN, cb); }, false);
    // Two simultaneous requests exercise independent native request ownership.
    await Promise.all([
        request('Manhattan forward', function (cb) { geocoder.forwardGeocoder('20 W 34th St, New York, NY', cb); }, true),
        request('Cupertino forward', function (cb) { geocoder.forwardGeocoder('1 Apple Park Way, Cupertino, CA', cb); }, true)
    ]);
    await request('Williamsburg forward', function (cb) { geocoder.forwardGeocoder('Williamsburg, Brooklyn, New York', cb); }, true,
        function (e) {
            if (!e.success) return;
            const p = e.places[0];
            ['locality', 'subLocality', 'subAdministrativeArea'].forEach(function (key) {
                check(typeof p[key] === 'string' && p[key].length > 0, 'Williamsburg forward ' + key, p[key]);
            });
        });
    await request('Brooklyn reverse', function (cb) { geocoder.reverseGeocoder(40.7178, -73.9580, cb); }, true,
        function (e) {
            if (!e.success) return;
            const p = e.places[0];
            ['locality', 'subLocality', 'subAdministrativeArea'].forEach(function (key) {
                check(typeof p[key] === 'string' && p[key].length > 0, 'Brooklyn reverse ' + key, p[key]);
            });
        });
    await request('London forward', function (cb) { geocoder.forwardGeocoder('10 Downing Street, London, UK', cb); }, true);
    await request('Paris reverse', function (cb) { geocoder.reverseGeocoder(48.8584, 2.2945, cb); }, true);
    if (mode === 'granted') {
        const pending = request('current place', function (cb) { geocoder.getCurrentPlace(cb); }, true);
        await request('current place busy', function (cb) { geocoder.getCurrentPlace(cb); }, false,
            function (e) { check(e.code === 'busy', 'busy error payload'); });
        await pending;
    } else {
        await request('current place denied', function (cb) { geocoder.getCurrentPlace(cb); }, false,
            function (e) { check(e.code === 'permission_denied', 'denied error payload'); });
    }
    // Leave a short observation window for unexpected duplicate completions.
    setTimeout(function () {
        report.complete = true;
        report.failures = report.checks.filter(function (c) { return !c.ok; }).length;
        save();
        output.value += '\nCOMPLETE failures=' + report.failures;
        Ti.API.info('[GeocoderCheck] COMPLETE failures=' + report.failures);
    }, 3000);
}
win.addEventListener('open', function () { setTimeout(run, 500); });
win.open();
