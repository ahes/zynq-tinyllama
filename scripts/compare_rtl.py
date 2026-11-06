"""Compare regenerated RTL with the measured reference, ignoring the Git header only."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
actual = ROOT / 'zynq7035_port/rtl/DataPath_xN.v'
reference = ROOT / 'evidence/round55/DataPath_xN_reference.v'
def normalize(path):
    return '\n'.join(line for line in path.read_text().splitlines() if not line.startswith('// Git hash'))
report = dict(passed=normalize(actual) == normalize(reference),
              sha256=hashlib.sha256(actual.read_bytes()).hexdigest().upper(),
              reference_sha256=hashlib.sha256(reference.read_bytes()).hexdigest().upper(),
              ignored_difference='SpinalHDL Git hash comment only')
out = ROOT / 'build/rtl_comparison.json'
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
if not report['passed']:
    raise SystemExit('Regenerated hardware differs from the measured Round55 reference')
