// Hotswap - unlimited attribute resets.
//
// Making a build by hand means respeccing over and over, and the game allows one reset per
// playthrough. That limit is a single quest fact, read in three places in this controller and
// nowhere else in the scripts. Clearing it at all three frees saves that already used their reset,
// keeps the button available after each use, and covers a quest setting it while the screen is open.
//
// The fact isn't the only thing in the way. CanSellNewPerks refuses the reset while cyberware depends
// on a perk being sold, which is every V with a full set of chrome. Its checks are also one perk at a
// time, though the reset sells them all at once, so it can pass and still leave V over capacity.
//
// So when something has to come off first, the reset becomes a swap: a plan for no perks, base
// attributes and V's cyberware minus what can't stay. The swap takes all cyberware off, resets, and
// puts back what fits, checking every result and rolling back if one fails. A V with nothing in the
// way gets the game's own reset, with its confirmation, refund and animation. Combat still refuses
// it, as the game does.

public abstract class HotswapReset {

  private static func AddSlot(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32, out off: array<ItemID>) -> Void {
    let item = HotswapGear.Raw(ctx, area, slot);
    if ItemID.IsValid(item) {
      ArrayPush(off, item);
    }
  }

  // What a piece costs with no perks. Cyberware Tinkerer takes a point off some pieces, and each of
  // those carries the discount as a stat.
  private static func CostWithoutPerks(ctx: ref<HotswapContext>, item: ItemID) -> Float {
    let data = ctx.ItemData(item);
    if !IsDefined(data) {
      return 0.0;
    }
    return data.GetStatValueByType(gamedataStatType.HumanityAllocated) + data.GetStatValueByType(gamedataStatType.Tech_Central_Milestone_2_Discount);
  }

  // The biggest piece still on, so as few as possible come off. The operating system and arms go only
  // if nothing else is left, and eyes and capacity boosters stay, since neither can help here.
  private static func Biggest(ctx: ref<HotswapContext>, const off: script_ref<array<ItemID>>, core: Bool) -> ItemID {
    let best = ItemID.None();
    let most = 0.0;
    let loadout = ctx.equip.GetEquipment();
    for area in loadout.equipAreas {
      let isCore = Equals(area.areaType, gamedataEquipmentArea.SystemReplacementCW) || Equals(area.areaType, gamedataEquipmentArea.ArmsCW);
      if HotswapNames.IsCyberwareArea(area.areaType) && NotEquals(area.areaType, gamedataEquipmentArea.EyesCW) && Equals(isCore, core) {
        for slot in area.equipSlots {
          let item = slot.itemID;
          if ItemID.IsValid(item) && !ArrayContains(Deref(off), item) && !HotswapGear.IsBooster(ctx, item) && !HotswapGear.IsPinned(ctx, item) {
            let size = HotswapReset.CostWithoutPerks(ctx, item);
            if size > most {
              most = size;
              best = item;
            }
          }
        }
      }
    }
    return best;
  }

  // What has to be off before every perk can be sold. These are the same rules as CanSellNewPerk, for
  // the whole sale at once instead of one perk at a time.
  public static func MustComeOff(ctx: ref<HotswapContext>) -> array<ItemID> {
    let off: array<ItemID>;
    // Slots that only exist with a perk.
    HotswapReset.AddSlot(ctx, gamedataEquipmentArea.MusculoskeletalSystemCW, 2, off);
    HotswapReset.AddSlot(ctx, gamedataEquipmentArea.HandsCW, 1, off);
    let skin = gamedataEquipmentArea.IntegumentarySystemCW;
    let slot = 0;
    let count = ctx.equip.GetEquipAreaIndex(skin) >= 0 ? ctx.equip.GetNumberOfSlots(skin, true) : 0;
    while slot < count {
      let item = HotswapGear.Raw(ctx, skin, slot);
      if ItemID.IsValid(item) && RPGManager.IsItemAdaptiveStemCells(ItemID.GetTDBID(item)) {
        ArrayPush(off, item);
      }
      slot += 1;
    }
    // With no perks, capacity loses what Driver Update and Edgerunner give, and the pieces Cyberware
    // Tinkerer discounts cost their full price. What stays on has to fit in that.
    let capacity = ctx.Stat(gamedataStatType.Humanity) - ctx.Stat(gamedataStatType.Tech_Central_Perk_2_2_Humanity);
    let used = 0.0;
    let loadout = ctx.equip.GetEquipment();
    for area in loadout.equipAreas {
      if HotswapNames.IsCyberwareArea(area.areaType) {
        for slot in area.equipSlots {
          if ItemID.IsValid(slot.itemID) && !ArrayContains(off, slot.itemID) {
            used += HotswapReset.CostWithoutPerks(ctx, slot.itemID);
          }
        }
      }
    }
    while used > capacity {
      let next = HotswapReset.Biggest(ctx, off, false);
      if !ItemID.IsValid(next) {
        next = HotswapReset.Biggest(ctx, off, true);
      }
      if !ItemID.IsValid(next) {
        break;
      }
      ArrayPush(off, next);
      used -= HotswapReset.CostWithoutPerks(ctx, next);
    }
    return off;
  }

  public static func Plan(ctx: ref<HotswapContext>, const off: script_ref<array<ItemID>>) -> ref<HotswapPlan> {
    let plan = new HotswapPlan();
    plan.name = HotswapText.ResetName();
    plan.free = true;
    plan.build = -1;
    let loadout = ctx.equip.GetEquipment();
    for area in loadout.equipAreas {
      if HotswapNames.IsCyberwareArea(area.areaType) {
        let slot = 0;
        let count = ArraySize(area.equipSlots);
        while slot < count {
          let live = area.equipSlots[slot].itemID;
          let want = new HotswapWant();
          want.area = area.areaType;
          want.slot = slot;
          want.item = ArrayContains(Deref(off), live) ? ItemID.None() : HotswapGear.Canon(ctx, area.areaType, live);
          ArrayPush(plan.gear, want);
          slot += 1;
        }
      }
    }
    let i = 0;
    let perks = HotswapNames.PerkCount();
    while i < perks {
      let perk = HotswapNames.PerkAt(i);
      if ctx.dev.IsNewPerkBought(perk) > 0 {
        let want = new HotswapPerkWant();
        want.perk = perk;
        want.level = 0;
        ArrayPush(plan.perks, want);
      }
      i += 1;
    }
    for stat in HotswapNames.Attributes() {
      let target = new HotswapAttributeWant();
      target.stat = stat;
      target.value = 3;
      ArrayPush(plan.attributeTargets, target);
      if Cast<Int32>(ctx.dev.GetAttributeValue(stat)) != 3 {
        let want = new HotswapAttributeWant();
        want.stat = stat;
        want.value = 3;
        ArrayPush(plan.attributes, want);
      }
    }
    return plan;
  }
}

@addField(NewPerksCategoriesGameController)
private let m_hotswapResetOff: array<ItemID>;

@addMethod(NewPerksCategoriesGameController)
private func HotswapFreeReset() -> Void {
  if IsDefined(this.m_questSystem) {
    this.m_questSystem.SetFact(n"ResetAttributeDisabled", 0);
  }
}

@wrapMethod(NewPerksCategoriesGameController)
private final func ResolveResetAttributesButtonVisibility() -> Void {
  this.HotswapFreeReset();
  wrappedMethod();
}

@addMethod(NewPerksCategoriesGameController)
private func HotswapTell(title: String, body: String) -> Void {
  this.m_resetConfirmationToken = GenericMessageNotification.Show(this, title, body, GenericMessageNotificationType.Confirm);
  this.m_resetConfirmationToken.RegisterListener(this, n"OnResetFailed");
}

// True when the reset was taken over, and the game's handler must not run.
@addMethod(NewPerksCategoriesGameController)
private func HotswapOfferReset() -> Bool {
  let ctx = HotswapContext.Make(this.m_player);
  let sys = HotswapSystem.Get(this.m_player.GetGame());
  if !IsDefined(ctx) || !IsDefined(sys) {
    return false;
  }
  let off = HotswapReset.MustComeOff(ctx);
  if ArraySize(off) == 0 {
    return false;
  }
  let refusal = HotswapGuards.Refusal(ctx, sys, HotswapReset.Plan(ctx, off));
  if StrLen(refusal) > 0 {
    this.HotswapTell(HotswapText.ResetTitle(), refusal);
    return true;
  }
  this.m_hotswapResetOff = off;
  let names: array<String>;
  for item in off {
    ArrayPush(names, HotswapGear.DisplayName(ctx, item));
  }
  this.m_resetConfirmationToken = GenericMessageNotification.Show(this, HotswapText.ResetTitle(), HotswapText.ResetBody(names), GenericMessageNotificationType.YesNo);
  this.m_resetConfirmationToken.RegisterListener(this, n"HotswapOnResetChoice");
  return true;
}

@wrapMethod(NewPerksCategoriesGameController)
protected cb func OnResetAttributesButtonClick(evt: ref<inkPointerEvent>) -> Bool {
  this.HotswapFreeReset();
  if (evt.IsAction(n"click") || evt.IsAction(n"tap")) && !this.m_player.IsInCombat() && this.HotswapOfferReset() {
    return false;
  }
  return wrappedMethod(evt);
}

@addMethod(NewPerksCategoriesGameController)
protected cb func HotswapOnResetChoice(data: ref<inkGameNotificationData>) -> Bool {
  this.m_resetConfirmationToken = null;
  let closed = data as GenericMessageNotificationCloseData;
  let ctx = HotswapContext.Make(this.m_player);
  let sys = HotswapSystem.Get(this.m_player.GetGame());
  if !IsDefined(closed) || !IsDefined(ctx) || !IsDefined(sys) || NotEquals(closed.result, GenericMessageNotificationResult.Yes) {
    return false;
  }
  sys.SetResetScreen(this);
  sys.Start(ctx, HotswapReset.Plan(ctx, this.m_hotswapResetOff));
  return true;
}

@addMethod(NewPerksCategoriesGameController)
public func HotswapResetFinished(report: ref<HotswapReport>) -> Void {
  this.ResolveResetAttributesButtonVisibility();
  this.QueueEvent(new PlayerDevUpdateDataEvent());
  if report.succeeded {
    this.PlaySound(n"Attributes", n"OnDone");
    this.PlayLibraryAnimation(n"panel_categories_reset_attributes");
  } else {
    this.HotswapTell(HotswapText.ResetTitle(), HotswapText.ReportLine(report) + "\n" + report.reason);
  }
}

@wrapMethod(NewPerksCategoriesGameController)
protected cb func OnResetConfirmed(data: ref<inkGameNotificationData>) -> Bool {
  let result = wrappedMethod(data);
  this.HotswapFreeReset();
  this.ResolveResetAttributesButtonVisibility();
  return result;
}
