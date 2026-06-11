"""Check whether generated WAV files contain audible speech."""
import sys
from pathlib import Path

import numpy as np
import torchaudio

paths = sorted(Path("output").glob("dramabox_*.wav"), key=lambda p: p.stat().st_mtime, reverse=True)[:6]
if not paths:
    print("No WAV files in output/")
    sys.exit(1)

for path in paths:
    wav, sr = torchaudio.load(str(path))
    arr = wav.numpy()
    peak = float(np.nanmax(np.abs(arr))) if arr.size else 0.0
    rms = float(np.sqrt(np.nanmean(arr**2))) if arr.size else 0.0
    nan = int(np.isnan(arr).sum())
    inf = int(np.isinf(arr).sum())
    dur = arr.shape[-1] / sr
    silent = peak < 1e-4
    print(f"{path.name}: dur={dur:.1f}s sr={sr} peak={peak:.4f} rms={rms:.4f} nan={nan} inf={inf} silent={silent}")
