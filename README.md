# Hotswap

Hotswap keeps up to five complete builds for V in Cyberpunk 2077 and switches between them from the
inventory in one click. A build covers cyberware, quickhacks, weapons, weapon mods, quick items, perks
and attributes. You can go from a quiet netrunner to a melee bruiser without visiting a ripperdoc or
respeccing by hand.

If you'd rather not plan a build yourself, each slot can suggest five builds made from the gear V
already owns.

> **Early access.** Hotswap has been tested on Cyberpunk 2077 2.5, but every save and mod list is
> different, so there will be bugs nobody has found yet. Make a save before you install it. If
> something goes wrong, please open a bug report on the Hotswap Nexus page. See
> [Reporting a bug](#reporting-a-bug) for what to include.

## Requirements

- Cyberpunk 2077 2.5
- [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885)

Optional: [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107). Hotswap runs
without it, but CET is what writes Hotswap's log, and the log is what makes a bug report useful.

## Installing

**With Vortex:** install the required mods first, then add the Hotswap zip with "Install From File"
and enable it.

**By hand:** install the required mods first, then extract the zip into your Cyberpunk 2077 folder,
the one that holds `bin`, `r6` and `Cyberpunk2077.exe`. The scripts should end up in
`r6\scripts\Hotswap`.

To update, install the new version over the old one.

To uninstall, disable Hotswap in Vortex or delete the `r6\scripts\Hotswap` folder. V keeps whatever
build they have on. Your saved builds are stored in your save, so if you save the game while Hotswap
is uninstalled, that save loses them.

## Using Hotswap

Open the inventory. The five build slots stand in a column to the right of OUTFIT.

Hover a slot and press:

| Key | On an empty slot | On a slot holding a build |
|---|---|---|
| Left click / A | Save V's current build here | Switch to it |
| R / Y | Show recommended builds | Save over it |
| V / X | | Rename it |
| X / Right stick | | Clear it |
| Z | | Show recommended builds (keyboard only) |

On a controller, Y saves over a build, so to see recommended builds for a slot that already holds
one, clear the slot first.

A dark slot is empty. The slot holding the build V is wearing lights up, and the light goes out as
soon as you change V's gear, perks or attributes yourself. Hover any build to see what switching to
it would change.

### Switching builds

A switch changes V in the same order a respec at a ripperdoc would. All cyberware comes off, perks
and attributes are reset, attributes are assigned, then perks. Cyberware goes back on after that,
then weapon mods and weapons. Each step takes a moment, and saving is blocked until it finishes.

If anything fails to go on, V is put back the way they were and a popup says what failed. If a build
names an item V no longer has, Hotswap tells you before it starts and asks whether to go ahead
without it.

### Recommended builds

Press R (Y on a controller) on an empty slot. The slots change to show five builds, best fit for V
first:

- **Netrunner:** quickhacks and smart weapons, Intelligence first
- **Blade Dancer:** fast melee with blades, Reflexes first
- **Juggernaut:** heavy weapons and heavy hits, Body first
- **Ghost:** stealth and precise shots, Cool first
- **Techie:** charged tech weapons and explosives, Technical Ability first

Each build is made from what V owns at that moment, so two players with different inventories get
different builds, and the suggestions get better as V finds better gear.

- **Arms and operating system** come first, if V owns them: Monowire and a cyberdeck for a Netrunner,
  Gorilla Arms and Berserk for a Juggernaut, Mantis Blades and a Sandevistan for a Blade Dancer.
- **Cyberware** is picked by what each piece does. Second Heart goes into almost every build, melee
  builds get melee cyberware such as Microrotors and Dense Marrow, and a Ghost gets Optical Camo and
  Lynx Paws. The most valuable pieces go in first, so capacity is spent where it counts.
- **Weapons** are picked to suit the build. A stealth build takes a silenced pistol over a louder one
  that hits harder, and melee builds carry their melee weapon first.
- **Mods** are the best ones V owns for that build, moved onto the chosen weapons and arm cyberware.
- **Quickhacks** match the build: a Ghost loads quiet hacks, a Netrunner lethal ones.
- **Attributes** are spent around that gear, using the points V has earned.
- **Perks** are chosen one at a time for what the build carries, so a blade build skips shotgun perks
  and only takes the Relic ability for the arms it uses. Any points left over are yours to spend.
- If V owns two copies of something, the higher grade is used.

Hover a recommended build to see what it uses. Click it, confirm, and it's saved to the slot and V
switches to it straight away. Press R (Y on a controller) again to go back without choosing.

A build that can't work at all, such as a Netrunner without a cyberdeck, is greyed out and tells you
what's missing. Items in your stash aren't counted.

### Changing your build by hand

Hotswap also lifts two limits, so you can put a build together yourself before saving it:

- **Reset Attributes**, on the Character screen, can be used as many times as you like. If some of
  V's cyberware depends on perks the reset removes, Hotswap tells you which pieces have to come off
  and takes them off for you. They stay in V's inventory.
- **The Cyberware screen** in the inventory can equip and remove any cyberware V owns, wherever V is.
  You still need a ripperdoc to buy or upgrade cyberware.

## When a switch can't happen

You can't switch to a build that changes perks or attributes during combat. No build can be switched
during story moments that lock your gear, or while Sandevistan, Berserk or optical camo is active.

Builds belong to the save they were made in.

## Settings

Open Mod Settings and find Hotswap. You can allow builds that only change gear to be switched in
combat, set a cooldown between switches, and set an eddie cost for each switch. All three are off by
default.

## Compatibility

Hotswap has been checked for conflicts with Equipment-EX and Cyberware-EX. If a perk overhaul renames
perks, any perk a saved build can't find is skipped and listed before you switch.

## Reporting a bug

Please open a bug report on the Hotswap Nexus page and include:

- what you were doing when it happened
- your `bin\x64\plugins\cyber_engine_tweaks\gamelog.log`, if you have Cyber Engine Tweaks. Close the
  game first, since the file is only fully written on exit. The lines starting with `[Hotswap]` show
  what happened during each switch.
- a crash report, if the game crashed

## License

MIT
