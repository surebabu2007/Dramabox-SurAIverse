# DramaBox Gradio launcher (Windows RTX 4090 tuned)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True"
$env:LTX_DTYPE = "bf16"
$env:GRADIO_SHARE = "0"
$env:PYTHONIOENCODING = "utf-8"

& "$PSScriptRoot\venv\Scripts\python.exe" app.py
