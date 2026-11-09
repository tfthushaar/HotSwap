"""Makes patch 2.31's script sources build with the 2.5 game's script compiler.

The only script compiler available is the one that ships with the installed game (2.5), and it
checks every native declaration against the 2.5 engine. So the few native declarations that differ
between the patches are written the 2.5 way, and the 2.31 lines that use them are changed to match.
None of them is anything Hotswap uses: they belong to marketing popups, the weapon HUD, telemetry,
phone calls and character creation. Everything else stays exactly as 2.31 has it, including every
native that 2.31 doesn't have, which is what lets the result stand in for the 2.31 script cache.

The sources are the 2.31 dump at commit deb5cdac of CDPR-Modding-Documentation/Cyberpunk-Scripts,
a fixed snapshot, so line numbers below never move. Every change is printed, and a change that no
longer finds its target stops the run.

usage: fix_sources.py <2.31 scripts dir> <2.5 scripts dir (the game's tools\\redmod\\scripts)>
"""
import os
import re
import sys

root, ref = sys.argv[1], sys.argv[2]


def load(base, rel):
    return open(os.path.join(base, rel), encoding="utf-8-sig", errors="replace").read()


def save(rel, text):
    open(os.path.join(root, rel), "w", encoding="utf-8").write(text)


def fail(message):
    print("  NOT FOUND " + message)
    sys.exit(1)


def line_of(text, pattern):
    for line in text.split("\n"):
        if re.search(pattern, line):
            return line
    return None


def fix(rel, old, new):
    text = load(root, rel)
    if old not in text:
        fail(f"{rel}: {old.strip()[:70]!r}")
    save(rel, text.replace(old, new, 1))
    print(f"  {rel}: {old.strip()[:60]!r} -> {new.strip()[:60]!r}")


def take_25(rel, pattern):
    """Replaces 2.31's declaration line with the 2.5 one."""
    old = line_of(load(root, rel), pattern)
    new = line_of(load(ref, rel), pattern)
    if old is None or new is None:
        fail(f"{rel}: /{pattern}/")
    fix(rel, old, new)


def drop(rel, pattern):
    old = line_of(load(root, rel), pattern)
    if old is None:
        fail(f"{rel}: /{pattern}/")
    fix(rel, old + "\n", "")


def line_fix(rel, number, old, new):
    lines = load(root, rel).split("\n")
    if old not in lines[number - 1]:
        fail(f"{rel}:{number}: {old!r}")
    lines[number - 1] = lines[number - 1].replace(old, new, 1)
    save(rel, "\n".join(lines))
    print(f"  {rel}:{number}: {old!r} -> {new!r}")


# A shipped source error: a switch whose last case falls out of a function returning a CName.
rel = r"cyberpunk\UI\mappins\minimapMappins.script"
lines = load(root, rel).split("\n")
start = 617
while start > 0 and not re.match(r"\s*(private|public|protected)?\s*(const\s+)?function ", lines[start]):
    start -= 1
depth, end = 0, None
for i in range(start, len(lines)):
    depth += lines[i].count("{") - lines[i].count("}")
    if ("{" in lines[i] or "}" in lines[i]) and depth == 0 and i > start:
        end = i
        break
if end is None:
    fail(rel + ": end of GetStateForAttitude")
lines.insert(end, "\t\treturn '';")
save(rel, "\n".join(lines))
print(f"  {rel}: return '' added at the end of {lines[start].strip()[:60]!r}")

# Native declarations, written the 2.5 way.
drop(r"core\events\attachmentSlotsEvents.script", r"import var itemID : ItemID;")
drop(r"core\events\attachmentSlotsEvents.script", r"import var itemID : ItemID;")
fix(r"core\data\slotData.script", "\timport var weapon : SlotWeaponData;",
    "\timport var rightWeapon : SlotWeaponData;\n\timport var leftWeapon : SlotWeaponData;")
for rel, name in [(r"core\gameplay\psmImports.script", "IsActionJustTapped"),
                  (r"core\systems\targetingSystem.script", "GetCrosshairData"),
                  (r"core\systems\targetingSystem.script", "GetCurrentSpread"),
                  (r"core\systems\telemetry.script", "LogWeaponAttackPerformed"),
                  (r"core\systems\transactionSystem.script", "GiveItemByItemData"),
                  (r"core\systems\phoneManager.script", "ApplyPhoneCallRestriction"),
                  (r"cyberpunk\UI\fullscreen\pregame\characterCreationMenu.script", "ApplyChangeToOption")]:
    take_25(rel, r"import\s+(?:\w+\s+)*function\s+" + name + r"\s*\(")
for name in ["RequestMarketingConsentPopupType", "RequestMarketingConsentSignInVersionUpdate",
             "RequestMarketingConsentUpdate", "RequestMarketingConsentVersionUpdate"]:
    drop(r"core\ui\systemRequestsHandler.script", r"import\s+(?:\w+\s+)*function\s+" + name + r"\s*\(")
# GameplayLogicPackage_Record.Prereq, which 2.5 replaced with PrereqRecord.
line_fix(r"core\data\tweakDBRecords.script", 4628, "public import function Prereq() : CName;", "")
# Two classes 2.31 declares importonly and 2.5 import, and a native enum 2.5 stores as Uint32.
fix(r"core\data\itemData.script", "importonly abstract class gameItemData extends IScriptable",
    "import abstract class gameItemData extends IScriptable")
fix(r"core\ui\events.script", "importonly class inkActionName extends IScriptable",
    "import class inkActionName extends IScriptable")
fix(r"core\systems\uiSystem.script", "import enum gameuiPatchIntro\n", "import enum gameuiPatchIntro : Uint32\n")
# The inventory screen's controller, a script class in 2.31, is native in 2.5. Only the declaration
# line changes: every member stays as 2.31 has it.
fix(r"cyberpunk\UI\inventory\inventoryGameController.script",
    "\nclass gameuiInventoryGameController extends gameuiMenuGameController\n",
    "\nimport class gameuiInventoryGameController extends gameuiMenuGameController\n")

# The 2.31 lines that use those declarations, changed to the 2.5 shapes. A removed call becomes a
# plain assignment rather than an empty statement, so its function doesn't turn constexpr.
line_fix(r"cyberpunk\UI\fullscreen\notification\marketingConsentPopup.script", 187,
         "m_requestHandler.RequestMarketingConsentUpdate( m_questionOne_State, m_questionTwo_State );",
         "m_requestHandler = m_requestHandler;")
line_fix(r"cyberpunk\UI\fullscreen\pregame\singleplayerMenu.script", 1139,
         "m_requestHandler.RequestMarketingConsentSignInVersionUpdate();", "m_requestHandler = m_requestHandler;")
line_fix(r"cyberpunk\UI\fullscreen\pregame\singleplayerMenu.script", 1146,
         "m_requestHandler.RequestMarketingConsentPopupType();", "m_requestHandler = m_requestHandler;")
for rel, number in [(r"cyberpunk\UI\interactions\looting.script", 117),
                    (r"cyberpunk\UI\inventory\inventoryDataManagerV2.script", 148),
                    (r"cyberpunk\UI\weapons\crosshairs\ironsight.script", 1173),
                    (r"cyberpunk\UI\weapons\weaponIndicatorController.script", 168),
                    (r"cyberpunk\UI\weapons\weaponRoster.script", 327),
                    (r"cyberpunk\UI\weapons\weaponRoster.script", 557)]:
    line_fix(rel, number, ".weapon", ".rightWeapon")
line_fix(r"cyberpunk\player\player.script", 2355, "evt.itemID", "ItemID.None()")
line_fix(r"cyberpunk\projectiles\projectileHelper.script", 55,
         "GetCrosshairData( ownerObject,", "GetCrosshairData( ownerObject.GetEntityID(), ownerObject,")
line_fix(r"cyberpunk\player\psm\meleeTransitions.script", 2501,
         "LogWeaponAttackPerformed( GetWeaponObject( scriptInterface ) )",
         "LogWeaponAttackPerformed( GetWeaponObject( scriptInterface ), \"\", \"\" )")
line_fix(r"cyberpunk\player\psm\meleeTransitions.script", 5493,
         "LogWeaponAttackPerformed( GetWeaponObject( scriptInterface ) )",
         "LogWeaponAttackPerformed( GetWeaponObject( scriptInterface ), \"\", \"\" )")
line_fix(r"cyberpunk\player\psm\weaponTransitions.script", 2465,
         "LogWeaponAttackPerformed( weapon )", "LogWeaponAttackPerformed( weapon, \"\", \"\" )")
line_fix(r"cyberpunk\systems\phoneSystem.script", 196,
         "ApplyPhoneCallRestriction( false )", "ApplyPhoneCallRestriction( false, false )")
line_fix(r"cyberpunk\systems\phoneSystem.script", 204,
         "ApplyPhoneCallRestriction( true )", "ApplyPhoneCallRestriction( true, false )")
