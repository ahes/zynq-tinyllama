"""Download/verify the pinned checkpoint, expand GQA and regenerate the FPGA files."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8*1024*1024), b''):
            h.update(block)
    return h.hexdigest().upper()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    record = json.loads((ROOT / 'model/SOURCE.json').read_text())
    original, mha, out = (ROOT / 'assets' / name for name in ('original', 'mha', 'sdcard'))
    if args.download:
        from huggingface_hub import snapshot_download
        snapshot_download(repo_id=record['repo_id'], revision=record['revision'],
                          allow_patterns=[r['name'] for r in record['files']], local_dir=original)
    for item in record['files']:
        path = original / item['name']
        if not path.is_file() or path.stat().st_size != item['bytes'] or sha(path) != item['sha256']:
            raise SystemExit('Original checkpoint missing or hash mismatch: ' + item['name'])
    for destination in (mha, out):
        if destination.exists() and any(destination.iterdir()):
            raise SystemExit('Refusing to reuse/overwrite a previous model build: ' + str(destination))
    mha.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    commands = [
        [sys.executable, '-u', str(ROOT / 'llama-fpga/python/expand_gqa_to_mha.py'), str(original), str(mha)],
        [sys.executable, '-u', str(ROOT / 'llama-fpga/python/model2bin.py'), '--source', 'fp-minmax',
         '--fp-model-path', str(mha), '--layout', str(ROOT / 'zynq7035_port/model_layout_zynq7035_1b.json'), '--output-dir', str(out)],
        [sys.executable, '-u', str(ROOT / 'llama-fpga/python/export_tokenizer_bin.py'), '--model-path', str(original), '--output', str(out / 'tkz.bin')],
    ]
    for command in commands:
        subprocess.run(command, check=True, cwd=ROOT)
    result = dict(model_bytes=(out / 'llm.bin').stat().st_size, model_sha256=sha(out / 'llm.bin'),
                  tokenizer_sha256=sha(out / 'tkz.bin'), source_revision=record['revision'])
    result['passed'] = (result['model_bytes'] == record['expected_model_bytes'] and
                        result['model_sha256'] == record['expected_model_sha256'] and
                        result['tokenizer_sha256'] == record['expected_tokenizer_sha256'])
    report = ROOT / 'build/model_result.json'
    report.parent.mkdir(exist_ok=True)
    report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    if not result['passed']:
        raise SystemExit('Rebuilt model/tokenizer does not match the board-tested image')

if __name__ == '__main__':
    main()
