"""Independent exhaustive binary16 oracle, float64 intermediate then RNE half."""
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'zynq7035_port/build/round55_dialogue_diagnosis_20261101/sampler_sim'
OUT.mkdir(exist_ok=True)
bits = np.arange(65536, dtype='<u2')
values = bits.view('<f2').astype(np.float64)
with np.errstate(invalid='ignore', over='ignore'):
    expected = np.where(values < 0, values*1.125, values/1.125).astype('<f2').view('<u2')
special = (bits & 0x7c00) == 0x7c00
expected[special] = bits[special]
(OUT / 'penalty_expected.hex').write_text(''.join(f'{int(v):04x}\n' for v in expected), encoding='ascii')
print('PENALTY_ORACLE_READY count=65536')
