# DramaBox Windows installer
#
# Sets up everything needed to run DramaBox: Python 3.11, Git, FFmpeg (via
# winget if missing), a fresh venv with CUDA-enabled PyTorch, and the rest of
# requirements.txt. Safe to re-run - already-satisfied steps are skipped.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "WARNING: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "ERROR: $msg" -ForegroundColor Red }

function Test-CommandExists($name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

# winget installs update the registry but not this process's $env:Path, so
# re-read both Machine and User PATH after each install.
function Update-PathFromRegistry {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Install-WithWinget($id, $friendlyName) {
    if (-not (Test-CommandExists "winget")) {
        Write-Warn "winget not found - cannot auto-install $friendlyName."
        return $false
    }
    Write-Step "Installing $friendlyName via winget ($id)..."
    try {
        winget install --id $id -e --silent `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity
    } catch {
        Write-Warn "$friendlyName winget install failed: $_"
        return $false
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "$friendlyName winget install exited with code $LASTEXITCODE."
        return $false
    }
    Update-PathFromRegistry
    return $true
}

function Ensure-Python311 {
    if (Test-CommandExists "py") {
        & py -3.11 --version *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python 3.11 found."
            return $true
        }
    }
    Write-Warn "Python 3.11 not found."
    if (Install-WithWinget "Python.Python.3.11" "Python 3.11") {
        if (Test-CommandExists "py") {
            & py -3.11 --version *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Python 3.11 installed successfully."
                return $true
            }
        }
    }
    Write-Err "Python 3.11 is required. Install it manually from https://www.python.org/downloads/release/python-3119/ (check 'Add python.exe to PATH'), then re-run Install.bat."
    return $false
}

function Ensure-Git {
    if (Test-CommandExists "git") {
        Write-Host "Git found."
        return $true
    }
    Write-Warn "Git not found."
    if (Install-WithWinget "Git.Git" "Git") {
        if (Test-CommandExists "git") {
            Write-Host "Git installed successfully."
            return $true
        }
    }
    Write-Err "Git is required (for the resemble-perth watermarking package). Install it manually from https://git-scm.com/download/win, then re-run Install.bat."
    return $false
}

function Ensure-FFmpeg {
    if (Test-CommandExists "ffmpeg") {
        Write-Host "FFmpeg found."
        return
    }
    Write-Warn "FFmpeg not found."
    if (Install-WithWinget "Gyan.FFmpeg" "FFmpeg") {
        if (Test-CommandExists "ffmpeg") {
            Write-Host "FFmpeg installed successfully."
            return
        }
    }
    Write-Warn "FFmpeg not on PATH. Some audio processing may not work. Manual install: https://www.gyan.dev/ffmpeg/builds/ (download 'release full', extract, add the bin\ folder to PATH)."
}

function Test-NvidiaGpu {
    if (Test-CommandExists "nvidia-smi") {
        Write-Host "NVIDIA GPU detected:"
        & nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
        return
    }
    Write-Warn "nvidia-smi not found - no NVIDIA GPU detected, or driver not installed."
    Write-Warn "DramaBox requires an NVIDIA GPU with ~24 GB VRAM. The app will not run without one."
}

function New-VenvIfNeeded {
    $venvPython = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
    if (Test-Path $venvPython) {
        & $venvPython --version *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Existing venv looks valid - skipping creation."
            return $venvPython
        }
        Write-Warn "Existing venv\ is broken - recreating."
        Remove-Item -Recurse -Force (Join-Path $PSScriptRoot "venv")
    }
    Write-Step "Creating virtual environment..."
    & py -3.11 -m venv (Join-Path $PSScriptRoot "venv")
    if ($LASTEXITCODE -ne 0) { throw "venv creation failed." }
    return $venvPython
}

function Install-PythonDeps($venvPython) {
    Write-Step "Upgrading pip..."
    & $venvPython -m pip install --upgrade pip

    Write-Step "Installing PyTorch 2.8.0 (CUDA 12.8 build)... this is large (~3 GB), please wait."
    & $venvPython -m pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
    if ($LASTEXITCODE -ne 0) { throw "torch/torchaudio install failed." }

    Write-Step "Installing remaining dependencies from requirements.txt..."
    # torch/torchaudio are already installed from the cu128 index above -
    # drop those two lines so plain PyPI doesn't overwrite them with CPU wheels.
    $reqLines = Get-Content (Join-Path $PSScriptRoot "requirements.txt") |
        Where-Object { $_ -notmatch '^\s*torch(==|\s|$)' -and $_ -notmatch '^\s*torchaudio(==|\s|$)' }
    $tmpReq = Join-Path $env:TEMP "dramabox-requirements-filtered.txt"
    $reqLines | Set-Content -Path $tmpReq -Encoding utf8
    try {
        & $venvPython -m pip install -r $tmpReq
        if ($LASTEXITCODE -ne 0) { throw "requirements.txt install failed." }
    } finally {
        Remove-Item $tmpReq -ErrorAction SilentlyContinue
    }
}

function Test-CudaWorks($venvPython) {
    Write-Step "Verifying CUDA..."
    & $venvPython -c "import torch; print('torch', torch.__version__); print('cuda_available', torch.cuda.is_available()); print('device', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'none')"
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "CUDA check script failed to run."
    }
}

function New-DesktopShortcut {
    Write-Step "Creating Desktop shortcut..."
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "DramaBox.lnk"
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $PSScriptRoot "Launch.bat"
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = "Launch DramaBox TTS"
    $shortcut.Save()
    Write-Host "Shortcut created: $shortcutPath"
}

# ---- Main ----
Write-Host "=== DramaBox Installer ===" -ForegroundColor Green

$pythonOk = Ensure-Python311
$gitOk = Ensure-Git
Ensure-FFmpeg
Test-NvidiaGpu

if (-not ($pythonOk -and $gitOk)) {
    Write-Err "Missing required prerequisites - see messages above. Aborting."
    exit 1
}

$venvPython = New-VenvIfNeeded
Install-PythonDeps $venvPython
Test-CudaWorks $venvPython
New-DesktopShortcut

Write-Host "`n=== Install complete ===" -ForegroundColor Green
Write-Host "Run DramaBox via the Desktop shortcut, Launch.bat, or .\launch.ps1"
Write-Host "First launch downloads ~17 GB of model weights (one-time, cached under %USERPROFILE%\.cache\dramabox\)."
