# Packages a clean, shareable copy of DramaBox into dist\DramaBox-release.zip
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$stagingDir = Join-Path $env:TEMP "DramaBox-release-staging"
$distDir    = Join-Path $PSScriptRoot "dist"
$zipPath    = Join-Path $distDir "DramaBox-release.zip"

if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
New-Item -ItemType Directory -Path $stagingDir | Out-Null
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

Write-Host "Staging files (excluding venv, output, .git, caches)..."

robocopy $PSScriptRoot $stagingDir /E `
    /XD ".git" "venv" "output" "__pycache__" ".cache" ".gradio" "third_party" "dist" `
    /XF "*.pyc" "*.pyo" "*.log" `
    /NFL /NDL /NJH /NJS | Out-Null

# robocopy exit codes 0-7 are success (bitmask of copy/extra/mismatch info);
# only >= 8 indicates an actual failure.
$rc = $LASTEXITCODE
if ($rc -ge 8) {
    throw "robocopy failed with exit code $rc"
}
Write-Host "robocopy exit code $rc (0-7 = success)"

# Reset $LASTEXITCODE so it doesn't leak robocopy's non-zero "success" code
# as this script's own exit code.
$global:LASTEXITCODE = 0

# Recreate an empty output/ dir so the app has somewhere to write on first run.
New-Item -ItemType Directory -Path (Join-Path $stagingDir "output") -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $stagingDir "output\.gitkeep") -Force | Out-Null

Write-Host "Compressing to $zipPath ..."
Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

Remove-Item -Recurse -Force $stagingDir

Write-Host "`nRelease package created: $zipPath"
Write-Host "Size: $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB"
