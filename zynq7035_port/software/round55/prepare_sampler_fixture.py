"""Independent float64 oracle for full-vocabulary and history-wrap scans."""
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'zynq7035_port/build/round55_dialogue_diagnosis_20261101'
rng = np.random.default_rng(551125)
for vocab, rows, name in ((32000, 12, 'sampler_sim'), (64, 140, 'sampler_small_sim')):
    target = OUT / name
    target.mkdir(exist_ok=True)
    logits = np.full((rows, vocab), -10, dtype='<f2')
    if vocab == 64:
        logits[:] = rng.normal(0, 2, (rows, vocab)).astype('<f2')
    logits[0, 10], logits[0, 20] = 5, 4.8
    logits[1] = logits[0]
    logits[2, 5], logits[2, 6] = -1, -1.05
    logits[3] = logits[2]
    logits[4, -1], logits[4, 10] = 8, 7.5
    logits[5] = logits[0]  # reset before this row
    logits[6, -1], logits[6, 10] = 8, 7.5
    logits[7] = logits[6]
    logits[8, 2], logits[8, 3] = 5, 4.9
    logits[9] = logits[8]  # EOS is exempt even when previously selected
    logits[10, 9], logits[10, 11] = np.nan, 1
    logits[11] = np.float16(-0.0)
    logits[11, 5] = np.float16(0.0)
    if vocab == 64:
        # After the reset, token4 occurs once. Verify it remains penalized at
        # age128, then expires at age129. The alternate61 is absent too.
        logits[6:] = -10
        logits[6, 4] = 8
        for row in range(7, 134):
            logits[row, 10 + row % 50] = 8
        logits[134:136, 4] = 5
        logits[134:136, 61] = 4.8
        for row in range(136, rows):
            logits[row, row % 64] = 8
    history, expected = [], []
    for row, values in enumerate(logits):
        if row == 5:
            history = []
        scores = values.astype(float)
        for token in set(history[-128:]):
            if token < 3:
                continue
            score = scores[token]
            scores[token] = np.float16(score*1.125 if score < 0 else score/1.125)
        legacy = int(np.argmax(np.where(np.isnan(values), -np.inf, values)))
        policy = int(np.argmax(np.where(np.isnan(scores), -np.inf, scores)))
        expected.append((legacy, policy))
        history.append(policy)
    (target / 'sampler_logits.hex').write_text(''.join(f'{int(v):04x}\n' for v in logits.view('<u2').ravel()), encoding='ascii')
    (target / 'sampler_expected.hex').write_text(''.join(f'{a:04x}{b:04x}\n' for a, b in expected), encoding='ascii')
    print('SAMPLER_ORACLE_READY', vocab, rows, expected[:12])
