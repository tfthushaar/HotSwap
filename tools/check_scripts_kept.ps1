<#
.SYNOPSIS
  Fails if a script from any earlier version of Hotswap is missing from src.

.DESCRIPTION
  Extracting a new version over an old one never removes a file. A script dropped from the mod stays
  on every install that updated that way, and redscript still compiles it. The moment something it
  calls is removed, that compile fails, and one failed compile stops every script mod the player has.

  So a script is never deleted. One that is no longer needed becomes an empty stub at the same path,
  and installing over the top replaces the old copy with the stub.

  The list of scripts comes from the whole git history, renames counted as removals. A repo with no
  scripts committed yet has nothing to check.
#>
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$history = & git -C $repo log --all --no-renames --format= --name-only -- src
if ($LASTEXITCODE -ne 0) { throw 'Could not read the git history.' }

$shipped = @($history | Where-Object { $_ -like '*.reds' } | Sort-Object -Unique)
$gone = @($shipped | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repo $_)) })

if ($gone.Count -gt 0) {
  $gone | ForEach-Object { Write-Host "  $_" }
  throw 'A script from an earlier version is gone. Restore it as a stub so old installs keep compiling.'
}
Write-Host "All $($shipped.Count) scripts from git history are still in src."
