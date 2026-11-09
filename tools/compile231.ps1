<#
.SYNOPSIS
  Compiles Hotswap the way a Cyberpunk 2077 2.31 player's game would.

.DESCRIPTION
  Hotswap ships one download for 2.5 and 2.31, so every change has to compile on both. This is the
  2.31 half. It needs the installed game (2.5) only for two things: REDmod's script compiler and its
  copy of the 2.5 sources.

  The first run builds a stand-in for the 2.31 script cache, which takes a few minutes and is kept:
    1. the 2.31 script sources, from the public dump (CDPR-Modding-Documentation/Cyberpunk-Scripts,
       commit deb5cdac)
    2. patch231\fix_sources.py, so the 2.5 compiler accepts them (see that file for every change)
    3. REDmod's scc.exe builds them, with the settings the game's own cache is built with
    4. patch231\to_pre25_layout.py turns the result into the cache layout 2.31 uses
  It also downloads the last redscript, Codeware and Mod Settings releases made for 2.31. Then it
  runs tools\compile.ps1 against all of that, so the result is the same check as on 2.5.

  Built the same way from the 2.5 sources, the stand-in comes out within 9 KB of the game's own
  19 MB cache, and Hotswap compiles against both alike.

.EXAMPLE
  ./tools/compile231.ps1
  ./tools/compile231.ps1 -Codeware 1.18.0
  ./tools/compile231.ps1 -Rebuild
#>
param(
  [string]$GameDir = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077',
  [string]$Work = (Join-Path $env:LOCALAPPDATA 'HotswapPatch231'),
  [ValidateSet('1.18.0', '1.20.6')]
  [string]$Codeware = '1.20.6',
  [string]$Extra = '',
  [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$here = $PSScriptRoot
$fixes = Join-Path $here 'patch231'
$sources = Join-Path $GameDir 'tools\redmod\scripts'
$scc = Join-Path $GameDir 'tools\redmod\bin\scc.exe'
$cache = Join-Path $Work 'final-2.31.redscripts'

foreach ($needed in @($sources, $scc)) {
  if (-not (Test-Path -LiteralPath $needed)) { throw "Not found: $needed (install the REDmod DLC)" }
}
New-Item -ItemType Directory -Force -Path $Work | Out-Null

# Each download goes to a folder of its own and is unpacked there.
function Get-Release([string]$Name, [string]$Url) {
  $dir = Join-Path $Work $Name
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
    $zip = Join-Path $dir 'release.zip'
    Write-Host "Downloading $Name"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $dir
  }
  return $dir
}

if ($Rebuild -or -not (Test-Path -LiteralPath $cache)) {
  $repo = Join-Path $Work 'Cyberpunk-Scripts'
  if (-not (Test-Path -LiteralPath $repo)) {
    Write-Host 'Cloning the script dumps'
    & git clone --quiet https://github.com/CDPR-Modding-Documentation/Cyberpunk-Scripts.git $repo
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
  }
  $tree = Join-Path $Work 'tree'
  if (Test-Path -LiteralPath $tree) { Remove-Item -LiteralPath $tree -Recurse -Force }
  New-Item -ItemType Directory -Path $tree | Out-Null
  $tar = Join-Path $Work 'scripts-2.31.tar'
  & git -C $repo archive --format=tar -o $tar deb5cdac
  if ($LASTEXITCODE -ne 0) { throw 'git archive failed' }
  & tar -xf $tar -C $tree
  if ($LASTEXITCODE -ne 0) { throw 'tar failed' }

  Write-Host 'Fixing the 2.31 sources for the 2.5 compiler'
  & python (Join-Path $fixes 'fix_sources.py') (Join-Path $tree 'scripts') $sources
  if ($LASTEXITCODE -ne 0) { throw 'fix_sources.py failed: the dump or the game changed' }

  Write-Host 'Building the 2.31 script cache (a few minutes)'
  $built = Join-Path $Work 'built-2.5-layout.redscripts'
  if (Test-Path -LiteralPath $built) { Remove-Item -LiteralPath $built -Force }
  $log = & $scc -compile (Join-Path $tree 'scripts') $built -threads 8 -profile off -optimize -no-breakpoint 2>&1 | ForEach-Object { "$_" }
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $built)) {
    $log | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    throw "scc.exe failed with exit code $LASTEXITCODE"
  }
  & python (Join-Path $fixes 'to_pre25_layout.py') $built $cache
  if ($LASTEXITCODE -ne 0) { throw 'to_pre25_layout.py failed' }
}

$redscript = Get-Release 'redscript-0.5.31' 'https://github.com/jac3km4/redscript/releases/download/v0.5.31/redscript-v0.5.31-windows.zip'
$codewareDir = Get-Release "codeware-$Codeware" "https://github.com/psiberx/cp2077-codeware/releases/download/v$Codeware/Codeware-$Codeware.zip"
$settings = Get-Release 'mod_settings-0.2.21' 'https://github.com/jackhumbert/mod_settings/releases/download/v0.2.21/mod_settings_v0.2.21.zip'

Write-Host "Compiling for 2.31: redscript 0.5.31, Codeware $Codeware, Mod Settings 0.2.21"
& (Join-Path $here 'compile.ps1') -GameDir $GameDir -Extra $Extra -BaseCache $cache `
  -Compiler (Join-Path $redscript 'engine\tools\scc.exe') `
  -Codeware (Join-Path $codewareDir 'red4ext\plugins\Codeware\Scripts') `
  -ModSettings (Join-Path $settings 'red4ext\plugins\mod_settings')
