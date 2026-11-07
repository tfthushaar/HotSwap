// Hotswap - comparing a saved build with V, changing nothing.
//
// A plan answers everything the row and the swap need to know: which items a build's rows mean today
// (cyberware upgrades give items new identities), what differs from what V has on, and whether the
// swap can start at all. Hovering a slot and starting a swap both build one.

public class HotswapWant {
  public let entry: wref<HotswapEntry>;
  public let area: gamedataEquipmentArea;
  public let slot: Int32;
  public let item: ItemID;      // invalid means the build wants this slot empty
  public let missing: Bool;     // the build names something V no longer has
}

public class HotswapPartWant {
  public let host: ItemID;
  public let attach: TweakDBID;
  public let part: ItemID;
  public let missing: Bool;
}

public class HotswapPerkWant {
  public let perk: gamedataNewPerkType;
  public let level: Int32;
}

public class HotswapAttributeWant {
  public let stat: gamedataStatType;
  public let value: Int32;
}

public class HotswapHotkeyWant {
  public let hotkey: EHotkey;
  public let item: ItemID;
}

public class HotswapPlan {
  public let build: Int32;
  public let name: String;
  public let gear: array<ref<HotswapWant>>;
  public let parts: array<ref<HotswapPartWant>>;
  public let perks: array<ref<HotswapPerkWant>>;              // only the perks that change
  public let attributes: array<ref<HotswapAttributeWant>>;    // only the attributes that change
  public let hotkeys: array<ref<HotswapHotkeyWant>>;
  public let missing: array<String>;
  public let refusal: String;
  public let free: Bool;                                      // no cooldown and no fee

  public let changedCyberware: Int32;
  public let changedParts: Int32;
  public let changedWeapons: Int32;
  public let changedQuick: Int32;
  public let capacityUsed: Float;
  public let capacityTotal: Float;
  public let sparePerkPoints: Int32;
  public let spareAttributePoints: Int32;

  public func ChangesDevelopment() -> Bool {
    return ArraySize(this.perks) > 0 || ArraySize(this.attributes) > 0;
  }

  // Lit in the row. A build with something missing is never lit, since V can't be wearing it.
  public func IsWorn() -> Bool {
    return !this.ChangesDevelopment()
      && this.changedCyberware == 0
      && this.changedParts == 0
      && this.changedWeapons == 0
      && this.changedQuick == 0
      && ArraySize(this.missing) == 0;
  }

  public func WantAt(area: gamedataEquipmentArea, slot: Int32) -> ref<HotswapWant> {
    for want in this.gear {
      if want.slot == slot && Equals(want.area, area) {
        return want;
      }
    }
    return null;
  }
}

// What V has earned, whatever it is currently spent on. These can only grow, and the swap checks
// they come out the same on the other side.
public class HotswapTotals {
  public let primary: Int32;
  public let relic: Int32;
  public let attribute: Int32;

  public static func Read(ctx: ref<HotswapContext>) -> ref<HotswapTotals> {
    let self = new HotswapTotals();
    self.primary = ctx.dev.GetDevPoints(gamedataDevelopmentPointType.Primary);
    self.relic = ctx.dev.GetDevPoints(gamedataDevelopmentPointType.Espionage);
    self.attribute = ctx.dev.GetDevPoints(gamedataDevelopmentPointType.Attribute);
    let i = 0;
    let count = HotswapNames.PerkCount();
    while i < count {
      let perk = HotswapNames.PerkAt(i);
      let level = ctx.dev.IsNewPerkBought(perk);
      if level > 0 {
        if ctx.dev.IsNewPerkEspionage(perk) {
          self.relic += level * HotswapTotals.RelicCost(ctx, perk);
        } else {
          self.primary += level;
        }
      }
      i += 1;
    }
    for stat in HotswapNames.Attributes() {
      self.attribute += Cast<Int32>(ctx.dev.GetAttributeValue(stat)) - 3;
    }
    return self;
  }

  // Relic milestones cost three points, everything else one.
  public static func RelicCost(ctx: ref<HotswapContext>, perk: gamedataNewPerkType) -> Int32 {
    return ctx.dev.IsEspionageMilestonePerk(perk) ? 3 : 1;
  }

  public func Matches(other: ref<HotswapTotals>) -> Bool {
    return this.primary == other.primary && this.relic == other.relic && this.attribute == other.attribute;
  }

  public func Describe() -> String {
    return s"perks \(this.primary), relic \(this.relic), attributes \(this.attribute)";
  }
}

public abstract class HotswapPlanner {

  public static func Make(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32) -> ref<HotswapPlan> {
    let plan = new HotswapPlan();
    plan.build = build;
    plan.name = sys.GetName(build);
    let rows = sys.EntriesOf(build);
    let bag = HotswapBag.Of(ctx);
    let installed = HotswapPlanner.InstalledParts(ctx);

    for row in rows {
      if row.kind == HotswapKindGear() {
        HotswapPlanner.AddGear(ctx, plan, bag, row);
      }
    }
    for row in rows {
      if row.kind == HotswapKindPart() {
        HotswapPlanner.AddPart(ctx, plan, bag, installed, row);
      }
      if row.kind == HotswapKindHotkey() {
        HotswapPlanner.AddHotkey(ctx, plan, row);
      }
    }
    HotswapPlanner.AddPerks(ctx, plan, rows);
    HotswapPlanner.AddAttributes(ctx, plan, rows);
    HotswapPlanner.CheckPoints(ctx, plan, rows);
    HotswapPlanner.Count(ctx, plan);
    return plan;
  }

  private static func AddGear(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, bag: ref<HotswapBag>, row: ref<HotswapEntry>) -> Void {
    let area = HotswapNames.ToArea(row.key);
    if Equals(area, gamedataEquipmentArea.Invalid) || !HotswapGear.SlotExists(ctx, area, row.value) {
      return;
    }
    let want = new HotswapWant();
    want.entry = row;
    want.area = area;
    want.slot = row.value;
    if ItemID.IsValid(row.item) {
      // The cyberware wheel and quick slots point at items that may sit in other rows too, so only
      // items that truly occupy one slot may claim.
      let shared = Equals(area, gamedataEquipmentArea.CyberwareWheel) || HotswapNames.IsQuickArea(area);
      want.item = shared ? HotswapPlanner.ResolveShared(ctx, bag, row.item) : bag.Resolve(ctx, row.item);
      if !ItemID.IsValid(want.item) {
        want.missing = true;
        ArrayPush(plan.missing, HotswapGear.DisplayName(ctx, row.item));
      }
    }
    ArrayPush(plan.gear, want);
  }

  private static func ResolveShared(ctx: ref<HotswapContext>, bag: ref<HotswapBag>, stored: ItemID) -> ItemID {
    if ctx.ts.HasItem(ctx.player, stored) {
      return stored;
    }
    let found = bag.FindUpgrade(stored);
    return ItemID.IsValid(found) ? found : bag.FindRecord(ItemID.GetTDBID(stored));
  }

  // A part sitting on a piece of cyberware isn't in the inventory, so it needs looking up separately
  // or every quickhack on the current deck would read as missing.
  private static func InstalledParts(ctx: ref<HotswapContext>) -> array<ItemID> {
    let parts: array<ItemID>;
    let loadout = ctx.equip.GetEquipment();
    for area in loadout.equipAreas {
      if HotswapNames.IsCyberwareArea(area.areaType) {
        for slot in area.equipSlots {
          if ItemID.IsValid(slot.itemID) {
            let attached = ItemModificationSystem.GetAllSlots(ctx.player, slot.itemID);
            for part in attached {
              if Equals(part.status, ESlotState.Taken) {
                ArrayPush(parts, part.installedPart);
              }
            }
          }
        }
      }
    }
    return parts;
  }

  private static func AddPart(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, bag: ref<HotswapBag>, const installed: script_ref<array<ItemID>>, row: ref<HotswapEntry>) -> Void {
    let host = HotswapPlanner.ResolveShared(ctx, bag, row.host);
    if !ItemID.IsValid(host) {
      return;
    }
    let want = new HotswapPartWant();
    want.host = host;
    want.attach = row.attach;
    want.part = row.item;
    let held = false;
    for id in Deref(installed) {
      if ItemID.GetTDBID(id) == ItemID.GetTDBID(row.item) {
        held = true;
      }
    }
    if !held {
      want.part = HotswapPlanner.ResolveShared(ctx, bag, row.item);
      if !ItemID.IsValid(want.part) {
        want.part = row.item;
        want.missing = true;
        ArrayPush(plan.missing, HotswapGear.DisplayName(ctx, row.item));
      }
    }
    ArrayPush(plan.parts, want);
  }

  private static func AddHotkey(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, row: ref<HotswapEntry>) -> Void {
    let want = new HotswapHotkeyWant();
    want.hotkey = Equals(row.key, n"RB") ? EHotkey.RB : EHotkey.DPAD_UP;
    want.item = row.item;
    if ctx.ts.HasItem(ctx.player, row.item) {
      ArrayPush(plan.hotkeys, want);
    }
  }

  private static func AddPerks(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, const rows: script_ref<array<ref<HotswapEntry>>>) -> Void {
    let wanted: array<Int32>;
    let count = HotswapNames.PerkCount();
    ArrayResize(wanted, count);
    for row in Deref(rows) {
      if row.kind == HotswapKindPerk() {
        if HotswapNames.PerkExists(row.key) {
          wanted[EnumInt(HotswapNames.ToPerk(row.key))] = row.value;
        } else {
          ArrayPush(plan.missing, NameToString(row.key));
        }
      }
    }
    let i = 0;
    while i < count {
      let perk = HotswapNames.PerkAt(i);
      if ctx.dev.IsNewPerkBought(perk) != wanted[i] {
        let want = new HotswapPerkWant();
        want.perk = perk;
        want.level = wanted[i];
        ArrayPush(plan.perks, want);
      }
      i += 1;
    }
  }

  private static func AddAttributes(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, const rows: script_ref<array<ref<HotswapEntry>>>) -> Void {
    for row in Deref(rows) {
      if row.kind == HotswapKindAttribute() {
        let stat = HotswapNames.ToStat(row.key);
        if NotEquals(stat, gamedataStatType.Invalid) && Cast<Int32>(ctx.dev.GetAttributeValue(stat)) != row.value {
          let want = new HotswapAttributeWant();
          want.stat = stat;
          want.value = row.value;
          ArrayPush(plan.attributes, want);
        }
      }
    }
  }

  // Totals only grow, so a saved build should always be affordable. This catches a save edited by
  // something else. Points left over are what V has earned since the build was made.
  private static func CheckPoints(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, const rows: script_ref<array<ref<HotswapEntry>>>) -> Void {
    let totals = HotswapTotals.Read(ctx);
    let primary = 0;
    let relic = 0;
    let attribute = 0;
    let haveAttributes = false;
    for row in Deref(rows) {
      if row.kind == HotswapKindPerk() && HotswapNames.PerkExists(row.key) {
        let perk = HotswapNames.ToPerk(row.key);
        if ctx.dev.IsNewPerkEspionage(perk) {
          relic += row.value * HotswapTotals.RelicCost(ctx, perk);
        } else {
          primary += row.value;
        }
      }
      if row.kind == HotswapKindAttribute() {
        haveAttributes = true;
        attribute += row.value - 3;
      }
    }
    if primary > totals.primary || relic > totals.relic {
      plan.refusal = HotswapText.NotEnoughPerkPoints();
    }
    if attribute > totals.attribute {
      plan.refusal = HotswapText.NotEnoughAttributePoints();
    }
    plan.sparePerkPoints = totals.primary - primary;
    plan.spareAttributePoints = haveAttributes ? totals.attribute - attribute : 0;
  }

  private static func Count(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>) -> Void {
    let total = ctx.Stat(gamedataStatType.Humanity) + ctx.Stat(gamedataStatType.Tech_Master_Perk_3_Humanity);
    let used = ctx.Stat(gamedataStatType.HumanityAllocated);
    for want in plan.gear {
      if !want.missing && !HotswapGear.Holds(ctx, want.area, want.slot, want.item) {
        if HotswapNames.IsCyberwareArea(want.area) {
          plan.changedCyberware += 1;
          used += HotswapGear.Capacity(ctx, want.item) - HotswapGear.Capacity(ctx, HotswapGear.Raw(ctx, want.area, want.slot));
        } else {
          if Equals(want.area, gamedataEquipmentArea.Weapon) {
            plan.changedWeapons += 1;
          } else {
            plan.changedQuick += 1;
          }
        }
      }
    }
    plan.capacityUsed = used;
    plan.capacityTotal = total;
    for part in plan.parts {
      if !part.missing && !HotswapPlanner.PartIsOn(ctx, plan, part) {
        plan.changedParts += 1;
      }
    }
  }

  // The item in the slot holding this host. That can be a generated copy of it.
  public static func LiveHost(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, host: ItemID) -> ItemID {
    for want in plan.gear {
      if HotswapNames.IsCyberwareArea(want.area) && HotswapGear.Same(want.item, host)
        && HotswapGear.Holds(ctx, want.area, want.slot, host) {
        return HotswapGear.Raw(ctx, want.area, want.slot);
      }
    }
    return ItemID.None();
  }

  // Quickhacks are compared by record, since a stack's seed can change without it being a new hack.
  public static func PartIsOn(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, want: ref<HotswapPartWant>) -> Bool {
    let host = HotswapPlanner.LiveHost(ctx, plan, want.host);
    if !ItemID.IsValid(host) {
      return false;
    }
    let slots = ItemModificationSystem.GetAllSlots(ctx.player, host);
    for slot in slots {
      if slot.slotID == want.attach && Equals(slot.status, ESlotState.Taken) {
        return ItemID.GetTDBID(slot.installedPart) == ItemID.GetTDBID(want.part);
      }
    }
    return false;
  }
}

// Things that stop a swap from starting, whatever the build holds. Each of these either breaks the
// game's own rules or would catch a system mid-use.
public abstract class HotswapGuards {

  public static func Refusal(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, plan: ref<HotswapPlan>) -> String {
    let player = ctx.player;
    if sys.IsBusy() {
      return HotswapText.Busy();
    }
    if player.IsReplacer() || player.IsJohnnyReplacer() {
      return HotswapText.NotAsJohnny();
    }
    if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"LockInHubMenu") {
      return HotswapText.Locked();
    }
    if !ctx.equip.IsWardrobeEnabled() {
      return HotswapText.Locked();
    }
    if HotswapGuards.AbilityRunning(ctx) {
      return HotswapText.AbilityRunning();
    }
    if player.IsInCombat() {
      if plan.ChangesDevelopment() || !sys.GetSettings().allowInCombat {
        return HotswapText.InCombat();
      }
    }
    if !plan.free {
      let wait = sys.CooldownLeft();
      if wait > 0.0 {
        return HotswapText.Cooldown(CeilF(wait));
      }
      let cost = sys.GetSettings().eddieCost;
      if cost > 0 && ctx.ts.GetItemQuantity(player, MarketSystem.Money()) < cost {
        return HotswapText.CantAfford(cost);
      }
    }
    return plan.refusal;
  }

  private static func AbilityRunning(ctx: ref<HotswapContext>) -> Bool {
    return StatusEffectSystem.ObjectHasStatusEffectOfType(ctx.player, gamedataStatusEffectType.Berserk)
      || StatusEffectSystem.ObjectHasStatusEffectOfType(ctx.player, gamedataStatusEffectType.Sandevistan)
      || StatusEffectSystem.ObjectHasStatusEffectWithTag(ctx.player, n"CamoActiveOnPlayer");
  }
}

public class HotswapReport {
  public let name: String;
  public let succeeded: Bool;
  public let rolledBack: Bool;
  public let reason: String;
  public let problems: array<String>;
}
