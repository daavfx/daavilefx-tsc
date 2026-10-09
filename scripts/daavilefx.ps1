# daavilefx.ps1 — the one-command entry point for the DAAVILEFX toolchain.
#
# Subcommands (all pass their exit code through, so gates and harnesses can
# rely on it: 0 = clean, 1 = type errors, 2 = crash/bad input):
#
#   daavilefx.ps1 check -Project <tsconfig> [extra tsgo args...]
#       Fast type check of a project (the CI / editor-save gate).
#       Example: daavilefx.ps1 check -Project F:\app\tsconfig.json
#
#   daavilefx.ps1 emit <files...> [extra tsgo args...]
#       Compile TypeScript to JavaScript.
#
#   daavilefx.ps1 typesyms -Project <tsconfig> -OutDir <dir>
#       Dump .types + .symbols for every project file (the RAG / RYIUK-memory
#       substrate: full type and symbol data as text).
#
#   daavilefx.ps1 version
#       Print tsgo/goport versions.
#
# Bins resolve from $env:DAAVILEFX_BINS, else <repo>\target\release.
# For the local-LLM harness: feed a file or project, read stdout/stderr,
# retry the model with the diagnostics. No JSON mode exists upstream —
# diagnostics are `file(line,col): error TSNNNN: message`, one per line,
# which is already machine-readable.
#
# NOTE on parameter names: -Project and -OutDir are deliberately NOT -p / -o,
# because PowerShell binds those against its own common parameters
# (-OutVariable, -OutBuffer) and rejects them as ambiguous.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('check', 'emit', 'typesyms', 'version')]
    [string]$Command,
    [string]$Project,
    [string]$OutDir,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Bins = if ($env:DAAVILEFX_BINS) { $env:DAAVILEFX_BINS } else { Join-Path $Repo 'target\release' }

function Get-Bin([string]$Name) {
    $p = Join-Path $Bins $Name
    if (-not (Test-Path $p)) { throw "missing binary: $p (build first: scripts\build-windows.ps1)" }
    return $p
}

switch ($Command) {
    'version' {
        & (Get-Bin 'tsgo.exe') --version
        & (Get-Bin 'goport.exe') --version
    }
    'check' {
        if (-not $Project) { throw "usage: daavilefx.ps1 check -Project <tsconfig> [extra tsgo args...]" }
        if ($Project -notlike '*.json') { throw "-Project must point at a tsconfig.json file, got: $Project" }
        & (Get-Bin 'tsgo.exe') --noEmit -p $Project @Rest
        exit $LASTEXITCODE
    }
    'emit' {
        if ($Rest.Count -eq 0) { throw "usage: daavilefx.ps1 emit <files...> [extra tsgo args...]" }
        & (Get-Bin 'tsgo.exe') @Rest
        exit $LASTEXITCODE
    }
    'typesyms' {
        if (-not $Project -or -not $OutDir) {
            throw "usage: daavilefx.ps1 typesyms -Project <tsconfig> -OutDir <dir>"
        }
        if ($Project -notlike '*.json') { throw "-Project must point at a tsconfig.json file, got: $Project" }
        & (Get-Bin 'goport_typesyms.exe') -p $Project -o $OutDir
        exit $LASTEXITCODE
    }
}
