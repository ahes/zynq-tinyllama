"""Package and inspect newly built FSBL, bitstream and application payloads."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8*1024*1024), b''):
            h.update(block)
    return h.hexdigest().upper()

def elf_loads(path):
    data = path.read_bytes()
    assert data[:7] == b'\x7fELF\x01\x01\x01', 'Expected ELF32 little endian'
    header = struct.unpack_from('<16sHHIIIIIHHHHHH', data)
    assert header[2] == 40, 'Expected ARM ELF'
    loads = []
    for index in range(header[10]):
        kind, offset, _, address, size, memory, flags, _ = struct.unpack_from('<8I', data, header[5] + index*header[9])
        if kind == 1 and memory:
            loads.append(dict(address=address, size=size, memory=memory, data=data[offset:offset+size]))
    return header[4], loads

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bootgen', required=True, type=Path)
    args = parser.parse_args()
    out = ROOT / 'build/package'
    out.mkdir(parents=True, exist_ok=True)
    inputs = {
        'fsbl': ROOT / 'build/vitis/llama7035_fsbl/Debug/llama7035_fsbl.elf',
        'bit': ROOT / 'build/hardware/system.bit',
        'app': ROOT / 'build/vitis/llama7035_app/Debug/llama7035_app.elf',
    }
    for path in inputs.values():
        if not path.is_file():
            raise SystemExit('Missing newly built input: ' + str(path))
    hw = json.loads((ROOT / 'build/hardware/hardware_result.json').read_text())
    model = json.loads((ROOT / 'build/model_result.json').read_text())
    assert hw['passed'] and model['passed']
    def hwh(path):
        with zipfile.ZipFile(path) as package:
            names = [name for name in package.namelist() if name.endswith('.hwh')]
            assert len(names) == 1, 'Expected one hardware handoff in XSA'
            return package.read(names[0])
    software_xsas = list((ROOT / 'build/vitis/llama7035_repro/export/llama7035_repro/hw').glob('*.xsa'))
    assert len(software_xsas) == 1
    assert hwh(software_xsas[0]) == hwh(ROOT / 'build/hardware/system.xsa'), 'Software platform differs from implemented hardware'
    app_entry, app_loads = elf_loads(inputs['app'])
    assert app_entry == 0x100000
    assert all(0x100000 <= s['address'] < s['address'] + s['memory'] <= 0x1000000 for s in app_loads), 'App overlaps model'
    assert b'Build: round55 chat128 repetition penalty 1.125 20261101' in inputs['app'].read_bytes()
    bif = out / 'boot.bif'
    bif.write_text('the_ROM_image:\n{\n  [bootloader] "' + inputs['fsbl'].as_posix() + '"\n  "' + inputs['bit'].as_posix() + '"\n  "' + inputs['app'].as_posix() + '"\n}\n')
    boot_path = out / 'BOOT.BIN'
    subprocess.run([str(args.bootgen), '-arch', 'zynq', '-image', str(bif), '-o', str(boot_path), '-w', 'on'], check=True)
    boot = boot_path.read_bytes()
    assert struct.unpack_from('<II', boot, 0x20) == (0xAA995566, 0x584C4E58)
    iht, pht = struct.unpack_from('<II', boot, 0x98)
    assert struct.unpack_from('<I', boot, iht + 4)[0] == 3
    parts = [struct.unpack_from('<16I', boot, pht + i*64) for i in range(3)]
    assert all(sum(p) & 0xFFFFFFFF == 0xFFFFFFFF for p in parts)
    for index, key in ((0,'fsbl'),(2,'app')):
        entry, loads = elf_loads(inputs[key])
        part = parts[index]
        assert entry == part[4]
        for segment in loads:
            if segment['size']:
                offset = segment['address'] - part[3]
                assert 0 <= offset < offset + segment['size'] <= part[0]*4
                start = part[5]*4 + offset
                assert boot[start:start+segment['size']] == segment['data'], key + ' payload mismatch'
    bit = inputs['bit'].read_bytes()
    cursor = 2 + struct.unpack_from('>H',bit)[0] + 2
    while bit[cursor:cursor+1] != b'e':
        assert bit[cursor:cursor+1] in (b'a',b'b',b'c',b'd')
        cursor += 3 + struct.unpack_from('>H',bit,cursor+1)[0]
    size = struct.unpack_from('>I',bit,cursor+1)[0]
    payload = bit[cursor+5:]
    assert len(payload) == size
    packed = boot[parts[1][5]*4:parts[1][5]*4+parts[1][0]*4]
    swapped = b''.join(payload[i:i+4][::-1] for i in range(0,size,4))
    assert packed[:size] in (payload,swapped), 'PL payload mismatch'
    assert len(packed)-size < 64
    source = json.loads((ROOT / 'model/SOURCE.json').read_text())
    for name, expected in (('llm.bin',source['expected_model_sha256']),('tkz.bin',source['expected_tokenizer_sha256'])):
        path = ROOT / 'assets/sdcard' / name
        assert sha(path) == expected
    shutil.copyfile(boot_path, ROOT / 'assets/sdcard/BOOT.BIN')
    record = dict(passed=True, boot_sha256=sha(boot_path), boot_bytes=len(boot),
                  inputs={k:dict(path=v.relative_to(ROOT).as_posix(),sha256=sha(v)) for k,v in inputs.items()},
                  app_entry=hex(app_entry), app_memory_end=hex(max(s['address']+s['memory'] for s in app_loads)),
                  model_sha256=model['model_sha256'],tokenizer_sha256=model['tokenizer_sha256'],
                  new_fsbl_bsp=True, boot_payloads_verified=['new FSBL','new PL bitstream','new PS ELF'],
                  software_platform_matches_implemented_hwh=True,
                  board_validation='pending')
    (out / 'verification.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record))

if __name__ == '__main__':
    main()
