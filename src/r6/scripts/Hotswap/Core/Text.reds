// Hotswap - every line of text the player reads, in one place.

public abstract class HotswapText {

  public static func Busy() -> String = "A swap is already running."
  public static func NotAsJohnny() -> String = "V isn't the one in control right now."
  public static func Locked() -> String = "Builds can't be changed at this point in the story."
  public static func AbilityRunning() -> String = "Wait until V's cyberware ability ends."
  public static func InCombat() -> String = "Builds can't be changed in combat."
  public static func NotEnoughPerkPoints() -> String = "V doesn't have enough perk points for this build."
  public static func NotEnoughRelicPoints() -> String = "V doesn't have enough Relic points for this build."
  public static func NotEnoughAttributePoints() -> String = "V doesn't have enough attribute points for this build."
  public static func PerksStuck() -> String = "The game refused to change V's perks."
  public static func PointsMoved() -> String = "V's point totals changed unexpectedly."
  public static func GearStuck() -> String = "V's cyberware wouldn't come off."

  public static func Cooldown(seconds: Int32) -> String = s"Wait \(seconds)s before switching again."
  public static func CantAfford(cost: Int32) -> String = s"A swap costs \(cost) eddies."

  public static func Join(items: array<String>) -> String {
    let text = "";
    for item in items {
      text = StrLen(text) == 0 ? item : text + ", " + item;
    }
    return text;
  }

  public static func DidNotLand(items: array<String>) -> String {
    return "These wouldn't go on: " + HotswapText.Join(items) + ".";
  }

  public static func PerkName(perk: gamedataNewPerkType) -> String {
    let record = RPGManager.GetNewPerkRecord(perk);
    return IsDefined(record) ? GetLocalizedText(record.Loc_name_key()) : NameToString(HotswapNames.OfPerk(perk));
  }

  public static func ReportLine(report: ref<HotswapReport>) -> String {
    if report.rolledBack {
      if ArraySize(report.problems) > 0 {
        return "Couldn't switch to " + report.name + ", and these didn't go back: " + HotswapText.Join(report.problems) + ".";
      }
      return "Couldn't switch to " + report.name + ". V is back as they were.";
    }
    if ArraySize(report.problems) > 0 {
      return "Switched to " + report.name + ", except: " + HotswapText.Join(report.problems) + ".";
    }
    return "Switched to " + report.name + ".";
  }

  public static func EmptyTitle() -> String = "Empty build slot"
  public static func EmptyBody() -> String = "Click to save V's current build here, or open the recommended builds."

  public static func Changes(plan: ref<HotswapPlan>) -> String {
    let parts: array<String>;
    if plan.changedCyberware > 0 {
      ArrayPush(parts, s"\(plan.changedCyberware) cyberware");
    }
    if ArraySize(plan.perks) > 0 {
      ArrayPush(parts, s"\(ArraySize(plan.perks)) perks");
    }
    if ArraySize(plan.attributes) > 0 {
      ArrayPush(parts, s"\(ArraySize(plan.attributes)) attributes");
    }
    if plan.changedWeapons > 0 {
      ArrayPush(parts, s"\(plan.changedWeapons) weapons");
    }
    if plan.changedQuick > 0 {
      ArrayPush(parts, s"\(plan.changedQuick) quick items");
    }
    if plan.changedParts > 0 {
      ArrayPush(parts, s"\(plan.changedParts) quickhacks and attachments");
    }
    return ArraySize(parts) > 0 ? "Will change: " + HotswapText.Join(parts) : "V is wearing this build.";
  }

  public static func Tooltip(plan: ref<HotswapPlan>) -> String {
    let text = HotswapText.Changes(plan);
    text += "\nCapacity after swap: " + IntToString(RoundF(plan.capacityUsed)) + " / " + IntToString(RoundF(plan.capacityTotal));
    if ArraySize(plan.missing) > 0 {
      text += "\nMissing: " + HotswapText.Join(plan.missing);
    }
    if plan.spareAttributePoints > 0 || plan.sparePerkPoints > 0 {
      text += "\nUnspent after swap: " + IntToString(plan.spareAttributePoints) + " attribute, " + IntToString(plan.sparePerkPoints) + " perk";
    }
    return text;
  }

  public static func SaveTitle() -> String = "Save build"
  public static func SaveBody() -> String = "Name this build."
  public static func RenameTitle() -> String = "Rename build"
  public static func OverwriteTitle() -> String = "Save over this build?"
  public static func Overwrite(name: String) -> String = "Save V's current build over " + name + "?"
  public static func ClearTitle() -> String = "Clear this build?"
  public static func ClearBody(name: String) -> String = "Clear " + name + "? V keeps everything they have on."
  public static func ConfirmTitle() -> String = "Switch anyway?"
  public static func PartialBody(missing: array<String>) -> String = HotswapText.Join(missing) + " can't be found. Switch anyway?"
  public static func ReplaceTitle() -> String = "Replace this build?"
  public static func ReplaceBody(name: String, recommended: String) -> String = "Replace " + name + " with the recommended " + recommended + " build, and switch V to it now? Attributes, perks, cyberware, weapons and weapon mods all change."
  public static func AdoptTitle(name: String) -> String = "Switch to " + name + "?"
  public static func AdoptBody(slot: Int32, attributes: String) -> String {
    return "This saves the build in slot " + IntToString(slot + 1) + " and switches V to it now. Attributes, perks, cyberware, weapons and weapon mods all change.\nAttributes: " + attributes;
  }
  public static func FailedTitle() -> String = "Build not switched"

  public static func HintSwitch() -> String = "Switch to build"
  public static func HintSave() -> String = "Save current build"
  public static func HintSaveOver() -> String = "Save over"
  public static func HintRename() -> String = "Rename"
  public static func HintClear() -> String = "Clear"
  public static func HintRecommend() -> String = "Recommended builds"
  public static func HintCreate() -> String = "Create and switch"
  public static func HintBack() -> String = "Back to builds"

  public static func RowLabel() -> String = "Builds"
  public static func RowLabelNamed(name: String) -> String = "Builds: " + name
  public static func RecommendLabel(slot: Int32) -> String = "Recommended for slot " + IntToString(slot + 1)
  public static func DefaultName(slot: Int32) -> String = "Build " + IntToString(slot + 1)

  public static func RequiredMissing(build: String, need: String) -> String {
    return build + " can't work without " + need + ", and V doesn't own one.";
  }
  public static func RequiredUnusable(build: String, need: String, item: String) -> String {
    return build + " can't work without " + need + ", and V's " + item + " is beyond the capacity or attributes V has.";
  }

  public static func ResetName() -> String = "Reset"
  public static func ResetTitle() -> String = "Reset Attributes"
  public static func ResetBody(items: array<String>) -> String {
    return "This cyberware needs perks the reset removes, so it comes off first and stays in V's inventory: " + HotswapText.Join(items) + ".";
  }
}
