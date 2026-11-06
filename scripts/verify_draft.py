"""Verify the exported source/evidence set, then reanalyze the recorded board suite."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def main():
    manifest = json.loads((ROOT / 'SOURCE_MANIFEST.json').read_text(encoding='utf-8'))
    errors = []
    known = {'SOURCE_MANIFEST.json'}
    secret = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bhf_[A-Za-z0-9]{30,}|\bAKIA[A-Z0-9]{16}\b')
    for item in manifest['files']:
        relative = item['path']
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT) or relative in known:
            errors.append('Unsafe/duplicate manifest path: ' + relative)
            continue
        known.add(relative)
        if not path.is_file():
            errors.append('Missing: ' + relative)
            continue
        data = path.read_bytes()
        if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest().upper() != item['sha256']:
            errors.append('Digest/size mismatch: ' + relative)
        if len(data) >= 50 * 1024 * 1024 or secret.search(data):
            errors.append('File requires publication review: ' + relative)
    for path in ROOT.rglob('*'):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in {'.git', 'build', 'target', '__pycache__', 'assets', '.vivado-ai', '.Xil', 'NA'} for part in rel.parts):
            continue
        if rel.as_posix() not in known:
            errors.append('Unlisted file: ' + rel.as_posix())
    evidence = ROOT / 'evidence/round55'
    hardware = json.loads((evidence / 'hardware_hashes.json').read_text(encoding='utf-8-sig'))
    rtl = ROOT / 'zynq7035_port/rtl/DataPath_xN.v'
    reference = evidence / 'DataPath_xN_reference.v'
    if reference.is_file():
        normalize = lambda path: '\n'.join(line for line in path.read_text().splitlines() if not line.startswith('// Git hash'))
        if hashlib.sha256(reference.read_bytes()).hexdigest().upper() != hardware['rtl_sha256'] or normalize(reference) != normalize(rtl):
            errors.append('Regenerated RTL differs from measured Round55 beyond the Git header')
    elif hashlib.sha256(rtl.read_bytes()).hexdigest().upper() != hardware['rtl_sha256']:
        errors.append('Generated RTL differs from measured Round55')
    for relative, expected in hardware['production_sources'].items():
        path = ROOT / relative.replace('\\', '/')
        if hashlib.sha256(path.read_bytes()).hexdigest().upper() != expected:
            errors.append('Production source differs from measured Round55: ' + relative)
    analysis_script = ROOT / 'zynq7035_port/software/round55/analyze_board.py'
    spec = importlib.util.spec_from_file_location('round55_analysis', analysis_script)
    analyzer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(analyzer)
    result = analyzer.analyze(evidence / 'uart_board_20261101_210346.log')
    recorded = json.loads((evidence / 'uart_board_20261101_210346.log.analysis.json').read_text(encoding='utf-8-sig'))
    if result != recorded or not result['control_and_dma_checks_passed'] or result['eos_answers'] != 8 or result['length_limited_answers'] != 2:
        errors.append('Offline board log analysis differs from recorded evidence')
    report = dict(passed=not errors, manifest_files=len(known), board_answers=result['completed_answers'],
                  eos=result['eos_answers'], length_limited=result['length_limited_answers'], errors=errors,
                  scope='File integrity, limited secret patterns and recorded UART reanalysis only; no board or full build test')
    out = ROOT / 'build/draft_verification.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
    if errors:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
