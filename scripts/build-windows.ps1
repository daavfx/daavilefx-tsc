# Build script for Windows (PowerShell 5.1+).
#
# Replaces scripts/run-cargo-capped.sh for the Windows workflow: that script
# needs bash, cgroups-style CPU caps and a Go checkout. This one just builds.
#
# Usage:
#   scripts\build-windows.ps1            # release bins into target\release
#   scripts\build-windows.ps1 -Bins      # also copy the bins + libs to dist\
#   scripts\build-windows.ps1 -Tests     # build, then run the Rust unit tests
#
# Requirements: Rust 1.93+ with the MSVC toolchain (rustup default).
# No Go, no Node, no oracle needed. Libs (.d.ts) are embedded in the
# default build; only --features noembed needs a libs/ dir next to the bins.
param(
    [switch]$Bins,
    [switch]$Tests
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Invoke-Cargo($Arguments) {
    $p = Start-Process -FilePath 'cargo' -ArgumentList $Arguments `
        -WorkingDirectory $Repo -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "cargo $($Arguments -join ' ') failed with exit $($p.ExitCode)" }
}

Write-Host "== daavilefx-tsc: cargo build --release --locked --bins =="
Invoke-Cargo @('build', '--release', '--locked', '--bins')

$Release = Join-Path $Repo 'target\release'
$Expected = @('tsgo.exe', 'goport.exe', 'goport_typesyms.exe', 'goport_watch.exe',
    'goport_emit.exe', 'goport_build.exe', 'goport_multiprog.exe',
    'goport_live_programs.exe', 'astdump.exe')
foreach ($bin in $Expected) {
    $path = Join-Path $Release $bin
    if (-not (Test-Path $path)) { throw "missing expected binary: $path" }
    $mb = [math]::Round((Get-Item $path).Length / 1MB, 1)
    Write-Host ("  {0,-26} {1,6} MB" -f $bin, $mb)
}

Write-Host "== versions =="
& (Join-Path $Release 'tsgo.exe') --version
& (Join-Path $Release 'goport.exe') --version

if ($Bins) {
    $Dist = Join-Path $Repo 'dist'
    New-Item -ItemType Directory -Force -Path $Dist | Out-Null
    foreach ($bin in $Expected) { Copy-Item (Join-Path $Release $bin) $Dist -Force }
    Write-Host "== bins copied to $Dist =="
}

if ($Tests) {
    Write-Host "== cargo test --release --locked --workspace =="
    Write-Host "   (the go_baselines suite needs a Go checkout via TS_GO_REPO and is skipped here)"
    Invoke-Cargo @('test', '--release', '--locked', '--workspace', '--exclude', 'ts_goport')
    Invoke-Cargo @('test', '--release', '--locked', '-p', 'ts_goport', '--lib', '--bins')
}

Write-Host "done."
