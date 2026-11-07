<#
.SYNOPSIS
  Fails if any Hotswap script hands an array intrinsic anything but a named array.

.DESCRIPTION
  The array intrinsics (ArrayContains, ArraySize, ArrayFindFirst and the rest) work on the array in
  place, through a pointer. Given the result of a function call, a literal or a dereferenced
  script_ref, that pointer can be to memory the game has already let go. Reading it works until the
  memory is reused, and then the game crashes (0.1.3 did, in ArrayContains). The compiler accepts
  all of these, so this check is what keeps them out.

  Allowed as the first argument: a name, optionally with fields and indexes (list, this.m_list,
  area.equipSlots, rows[i]). Anything else must be stored in a local first.

.EXAMPLE
  ./tools/check_array_arguments.ps1
#>
param(
  [string]$Root = (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\r6\scripts\Hotswap')
)

$ErrorActionPreference = 'Stop'

$intrinsic = [regex]'\bArray(Contains|FindFirst|FindLast|Size|Count|Last|Pop|Push|Insert|Erase|Remove|Clear|Resize|Grow)\s*\('
$named = [regex]'^[A-Za-z_]\w*(\s*\.\s*[A-Za-z_]\w*|\[[^\[\]()]*\])*$'
$bad = @()

foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -Filter *.reds) {
  $text = [IO.File]::ReadAllText($file.FullName)
  foreach ($match in $intrinsic.Matches($text)) {
    # The first argument runs to the first comma or closing bracket at its own depth.
    $i = $match.Index + $match.Length
    $depth = 0
    $start = $i
    while ($i -lt $text.Length) {
      $c = $text[$i]
      if ($c -eq '(' -or $c -eq '[') { $depth++ }
      elseif ($c -eq ')' -or $c -eq ']') {
        if ($depth -eq 0) { break }
        $depth--
      }
      elseif ($c -eq ',' -and $depth -eq 0) { break }
      $i++
    }
    $argument = $text.Substring($start, $i - $start).Trim()
    if (-not $named.IsMatch($argument)) {
      $line = ($text.Substring(0, $match.Index) -split "`n").Count
      $relative = $file.FullName.Substring($Root.Length + 1)
      $call = $match.Value.Trim()
      $bad += ('{0}:{1}: {2}{3}, ...)' -f $relative, $line, $call, $argument)
    }
  }
}

if ($bad.Count -gt 0) {
  $bad | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw "$($bad.Count) array intrinsic(s) given something other than a named array. Store it in a local first."
}
Write-Host "Every array intrinsic gets a named array." -ForegroundColor Green
