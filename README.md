# Hotswap

Five build presets for Cyberpunk 2077 2.5. Save V's whole build, then switch to it from the inventory
with one click: cyberware, quickhacks, weapons, quick items, perks and attributes, with no ripperdoc
visit. Or let Hotswap make one for you from what V already owns.

> **Status: early and untested.** Everything compiles against the game, and against Equipment-EX and
> Cyberware-EX, but none of it has been played yet. Keep a save from before you install it.

## Requirements

- Cyberpunk 2077 2.5
- [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885)

## Installing

Install with a mod manager, or extract the zip into the game folder so that the scripts end up in
`r6/scripts/Hotswap`. To update, extract the new version over the old one.

## Using it

Open the inventory. The Builds column sits right beside OUTFIT, on the first page.

| Hover a slot and press | On an empty slot | On a slot holding a build |
|---|---|---|
| Left click / A | Save V's current build here | Switch to it |
| R / Y | Recommended builds | Save over it |
| V / X | | Rename |
| X / Right stick | | Clear |
| Z | | Recommended builds (keyboard) |

A dark slot is empty. A lit slot is what V is wearing now, and its light goes out if V's gear, perks or
attributes change by hand. Hovering a build shows what would change.

### Recommended builds

Each slot offers five kinds of build: **Netrunner**, **Blade Dancer**, **Juggernaut**, **Ghost** and
**Techie**, with the best fit for V first. None of them is a preset. Each is worked out from what V
owns at that moment: the guns and cyberware that suit it, then attributes and perks chosen to serve
that gear, using the points V has earned. Two players with different inventories get different
builds.

Hover one to read it, and click it. After you confirm, it's saved and V switches to it:
attributes, perks, cyberware, quickhacks, weapons and weapon mods, with no ripperdoc. Weapons are
chosen for what the build needs, so a stealth build takes a silenced pistol over a louder one that
hits harder. Each weapon gets the best mods V owns for that build. Where V has two copies of
something, the higher grade is used.

Recommendations are worked out fresh each time you open them, so they improve as V finds better
gear.

A build that can't work at all, like a Netrunner with no cyberdeck, is greyed out and says what's
missing. Items in the stash don't count.

### Making your own builds

Hotswap also removes two limits, so the game's own screens work as a build editor:

- **Reset Attributes**, on the Character screen, can be used as often as you like. If V's cyberware
  needs perks the reset removes, Hotswap says which pieces have to come off and takes them off for
  you. They stay in V's inventory.
- **The Cyberware screen** can equip and remove cyberware V owns, from anywhere. Buying and upgrading
  still happen at a ripperdoc.

## When a swap can't go cleanly

A switch goes in the order a respec does: all cyberware off, perks and attributes reset, attributes
assigned, then perks, then cyberware back on, then weapon mods and weapons.

Builds can't be changed in combat if they touch perks or attributes, during locked story moments, or
while Sandevistan, Berserk or optical camo is running. If something in a build is gone, a popup says
what and asks first. If a swap fails partway, V is put back as they were, and anything that didn't
go back is named. Saving is blocked while a swap runs.

Builds belong to the save they were made in. Uninstalling leaves V in whatever build they have on.

If a swap goes wrong, Hotswap writes what happened to `bin/x64/plugins/cyber_engine_tweaks/gamelog.log`,
in lines starting `[Hotswap]`. That file is what to send with a bug report.

## Settings

In Mod Settings: allow gear-only swaps in combat, seconds between swaps, and eddies per swap. All are
off by default.

## Compatibility

Compiles alongside Equipment-EX and Cyberware-EX. Perk overhauls can rename perks: names that no longer
resolve are skipped and reported.

## Building from source

`tools/compile.ps1` compiles in a throwaway folder with the game's own compiler, so the game folder is
left alone. `tools/package.ps1 -Version x.y.z` builds a release zip.

Before changing anything persisted, read the comment at the top of `Core/Types.reds`. Scripts are
never deleted: see `tools/check_scripts_kept.ps1`.

## License

MIT
