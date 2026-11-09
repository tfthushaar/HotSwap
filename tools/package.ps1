<#
.SYNOPSIS
  Builds dist/Hotswap-<Version>.zip, ready for a mod manager or to extract over the game folder.

.DESCRIPTION
  Stamps the version, checks that no earlier script has gone missing, then compiles for 2.5 and for
  2.31, since one download serves both. A release that fails any of those is not produced.

  The zip is written by hand and not with Compress-Archive, because Windows PowerShell 5.1 writes
  backslashes into entry names, and some extractors then flatten everything into one folder.

.EXAMPLE
  ./tools/package.ps1 -Version 0.1.0
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$Version
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repo 'src'
$dist = Join-Path $repo 'dist'
$versionFile = Join-Path $src 'r6\scripts\Hotswap\Core\Version.reds'

& (Join-Path $PSScriptRoot 'check_scripts_kept.ps1')

$numbers = $Version.Split('.') | ForEach-Object { [int]$_ }
$code = $numbers[0] * 10000 + $numbers[1] * 100 + $numbers[2]

# .NET rather than Set-Content, which would add a byte order mark on Windows PowerShell.
$text = [IO.File]::ReadAllText($versionFile)
$text = $text -replace 'HotswapVersion\(\) -> String = "[^"]*"', "HotswapVersion() -> String = `"$Version`""
$text = $text -replace 'HotswapVersionCode\(\) -> Int32 = \d+', "HotswapVersionCode() -> Int32 = $code"
[IO.File]::WriteAllText($versionFile, $text, (New-Object Text.UTF8Encoding $false))

& (Join-Path $PSScriptRoot 'compile.ps1')
& (Join-Path $PSScriptRoot 'compile231.ps1')
& (Join-Path $PSScriptRoot 'compile231.ps1') -Codeware 1.18.0

New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zipPath = Join-Path $dist "Hotswap-$Version.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$prefix = (Resolve-Path -LiteralPath $src).Path.TrimEnd('\') + '\'
$zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($file in Get-ChildItem -LiteralPath $src -Recurse -File) {
    $entry = $file.FullName.Substring($prefix.Length).Replace('\', '/')
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $file.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
}
finally {
  $zip.Dispose()
}

Write-Host "Built $zipPath"
