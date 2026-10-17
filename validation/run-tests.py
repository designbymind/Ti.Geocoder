#!/usr/bin/env python3
"""Run the real Titanium bridge suite on a booted simulator; no global install."""
import argparse
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--device', required=True, help='Booted simulator UDID')
parser.add_argument('--app', type=Path, required=True, help='Built GeocoderDemo.app')
parser.add_argument('--mode', choices=['denied', 'granted', 'both'], default='both')
args = parser.parse_args()
bundle = 'com.designbymind.geocoderdemo'
root = Path(__file__).resolve().parent

def sim(*arguments, check=True):
    result = subprocess.run(['xcrun', 'simctl', *arguments], text=True,
                            capture_output=True, timeout=60, check=check)
    if result.returncode and check:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()

sim('install', args.device, str(args.app.resolve()))
container = Path(sim('get_app_container', args.device, bundle, 'data')) / 'Documents'
container.mkdir(parents=True, exist_ok=True)
for mode in (['denied', 'granted'] if args.mode == 'both' else [args.mode]):
    sim('terminate', args.device, bundle, check=False)
    sim('privacy', args.device, 'grant' if mode == 'granted' else 'revoke', 'location', bundle)
    if mode == 'granted':
        sim('location', args.device, 'set', '40.7178,-73.9580')
    (container / 'mode.txt').write_text(mode)
    results = container / 'results.json'
    results.unlink(missing_ok=True)
    print(sim('launch', args.device, bundle), flush=True)
    deadline = time.monotonic() + 180
    report = None
    while time.monotonic() < deadline:
        try:
            report = json.loads(results.read_text())
            if report.get('complete'):
                break
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(1)
    else:
        raise RuntimeError(f'{mode}: suite did not complete within 180 seconds')
    output = root / 'results' / f'ios-{report["os"]}-{mode}.json'
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(f'{mode}: checks={len(report["checks"])} failures={report["failures"]}; {output}', flush=True)
    for name in ['Williamsburg forward', 'Brooklyn reverse', 'London forward', 'Paris reverse', 'current place']:
        places = report['responses'].get(name, {}).get('places', [])
        if places:
            print(name, {key: places[0].get(key) for key in ['locality', 'subLocality', 'subAdministrativeArea']}, flush=True)
    if report['failures']:
        raise SystemExit(1)
