<#
.SYNOPSIS
  Compiles Hotswap with the game's own redscript compiler, without touching the game folder.

.DESCRIPTION
  Hotswap only exists as a set of scripts, and one script that fails to compile stops every script
  mod a player has. So nothing is called finished until this passes.

  A throwaway folder gets a copy of the vanilla script cache, plus Hotswap and the mods it depends
  on. scc.exe writes its result there, so the install is left exactly as it was. A compile that
  fails is reported with the compiler's own errors and a non-zero exit code.

  -Extra adds folders of other mods' scripts to the same compile, separated by semicolons, which is
  how Hotswap is tested against Equipment-EX and friends without installing them.

  -BaseCache, -Compiler, -Codeware and -ModSettings replace the installed game's pieces, which is
  how Hotswap is tested against another game patch: that patch's script cache, and the redscript,
  Codeware and Mod Settings releases made for it. Each one left out comes from -GameDir.

.EXAMPLE
  ./tools/compile.ps1
  ./tools/compile.ps1 -Extra C:\temp\equipment-ex\scripts
  ./tools/compile.ps1 -BaseCache C:\temp\2.31\final.redscripts -Compiler C:\temp\redscript-0.5.31\engine\tools\scc.exe -Codeware C:\temp\codeware-1.20.6\red4ext\plugins\Codeware\Scripts -ModSettings C:\temp\mod_settings-0.2.21\red4ext\plugins\mod_settings
#>
param(
  [string]$GameDir = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077',
  [string]$Extra = '',
  [string]$BaseCache = '',
  [string]$Compiler = '',
  [string]$Codeware = '',
  [string]$ModSettings = ''
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$mod = Join-Path $repo 'src\r6\scripts\Hotswap'
$compiler = if ($Compiler) { $Compiler } else { Join-Path $GameDir 'engine\tools\scc.exe' }
$vanillaCache = if ($BaseCache) { $BaseCache } else { Join-Path $GameDir 'r6\cache\final.redscripts' }
$codeware = if ($Codeware) { $Codeware } else { Join-Path $GameDir 'red4ext\plugins\Codeware\Scripts' }
$modSettings = if ($ModSettings) { $ModSettings } else { Join-Path $GameDir 'red4ext\plugins\mod_settings' }

foreach ($needed in @($mod, $compiler, $vanillaCache, $codeware, $modSettings)) {
  if (-not (Test-Path -LiteralPath $needed)) { throw "Not found: $needed" }
}

# The compiler accepts code that crashes the game at run time. This catches the kind that has.
& (Join-Path $PSScriptRoot 'check_array_arguments.ps1') -Root $mod

$work = Join-Path ([IO.Path]::GetTempPath()) ("hotswap-compile-" + [Guid]::NewGuid().ToString('N'))
$scripts = Join-Path $work 'scripts'
New-Item -ItemType Directory -Path $scripts -Force | Out-Null

try {
  Copy-Item -LiteralPath $mod -Destination (Join-Path $scripts 'Hotswap') -Recurse
  Copy-Item -LiteralPath $codeware -Destination (Join-Path $scripts 'Codeware') -Recurse

  $settingsCopy = Join-Path $scripts 'mod_settings'
  New-Item -ItemType Directory -Path $settingsCopy | Out-Null
  Copy-Item -Path (Join-Path $modSettings '*.reds') -Destination $settingsCopy

  $n = 0
  foreach ($folder in ($Extra -split ';' | Where-Object { $_ })) {
    $n += 1
    Copy-Item -LiteralPath $folder -Destination (Join-Path $scripts "extra$n") -Recurse
  }

  $baseCache = Join-Path $work 'base.redscripts'
  $outCache = Join-Path $work 'out.redscripts'
  Copy-Item -LiteralPath $vanillaCache -Destination $baseCache

  $output = & $compiler -compile $scripts -outputCacheFile $outCache $baseCache 2>&1 | ForEach-Object { "$_" }
  $errors = @($output | Where-Object { $_ -match '\[(ERROR|UNRESOLVED|NO_MATCHING|SYNTAX|TYPE|WRONG)|^\s*ERROR|error:' })

  if ((Test-Path -LiteralPath $outCache) -and $errors.Count -eq 0) {
    $warnings = @($output | Where-Object { $_ -match 'WARN' })
    foreach ($line in $warnings) { Write-Host $line -ForegroundColor Yellow }
    $files = (Get-ChildItem -LiteralPath $mod -Recurse -Filter *.reds).Count
    Write-Host "OK: $files Hotswap scripts compile against this game." -ForegroundColor Green
  } else {
    $output | ForEach-Object { Write-Host $_ }
    throw "Compile failed."
  }
}
finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
