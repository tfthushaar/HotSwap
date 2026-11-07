// Hotswap - running a swap.
//
// Gear comes off, then perks and attributes change, then gear goes on. Each side's requirements are
// met by the step before it: taking cyberware off frees the capacity that lets capacity perks be
// sold, and setting attributes and perks first opens the slots and meets the requirements of what
// goes back on.
//
// Equip requests are queued and take effect later, and the capacity check inside EquipItem fails
// silently, so a stage never assumes anything worked. It reads the slots back until they match or it
// runs out of time. The game's own IsEquipPending can't help: the flag only exists inside one call.
//
// The clock is the same delayed request the outfit row uses, which is known to run with the menu
// open. A DelayCallback is set alongside it, so that if either one stops firing the swap still
// finishes rather than hanging. Whichever fires first wins and the generation number drops the other.

enum HotswapStage {
  Idle = 0,
  CyberOff = 1,
  WaitCyberOff = 2,
  Development = 3,
  Settle = 4,
  CyberOn = 5,
  WaitCyberOn = 6,
  PartsOff = 7,
  WaitPartsOff = 8,
  PartsOn = 9,
  WaitPartsOn = 10,
  WeaponsOff = 11,
  WaitWeaponsOff = 12,
  WeaponsOn = 13,
  WaitWeaponsOn = 14,
  Quick = 15,
  Finish = 16,
}

public class HotswapSlotRef {
  public let area: gamedataEquipmentArea;
  public let slot: Int32;

  public static func Make(area: gamedataEquipmentArea, slot: Int32) -> ref<HotswapSlotRef> {
    let self = new HotswapSlotRef();
    self.area = area;
    self.slot = slot;
    return self;
  }
}

public class HotswapApply {
  private let m_sys: wref<HotswapSystem>;
  private let m_ctx: ref<HotswapContext>;
  private let m_plan: ref<HotswapPlan>;
  private let m_stage: HotswapStage;
  private let m_running: Bool;
  private let m_generation: Int32;
  private let m_waited: Int32;
  private let m_lastTickAt: Float;
  private let m_isUndo: Bool;
  private let m_stripped: Bool;
  private let m_totals: ref<HotswapTotals>;
  private let m_cleared: array<ref<HotswapSlotRef>>;
  private let m_problems: array<String>;
  private let m_reason: String;
  private let m_name: String;

  private func TickSeconds() -> Float = 0.1
  private func WaitLimit() -> Int32 = 20
  private func StallSeconds() -> Float = 8.0

  public func IsRunning() -> Bool {
    return this.m_running;
  }

  public func IsStalled() -> Bool {
    return this.Now() - this.m_lastTickAt > this.StallSeconds();
  }

  private func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(this.m_ctx.game));
  }

  public func Begin(sys: ref<HotswapSystem>, ctx: ref<HotswapContext>, plan: ref<HotswapPlan>) -> Void {
    this.m_sys = sys;
    this.m_ctx = ctx;
    this.m_plan = plan;
    this.m_name = plan.name;
    this.m_running = true;
    this.m_lastTickAt = this.Now();
    this.m_totals = HotswapTotals.Read(ctx);
    HotswapCapture.Into(ctx, sys, HotswapUndoBuild());
    HSLog(s"Swap to \(plan.name) begins. \(this.m_totals.Describe())");
    this.Enter(HotswapStage.CyberOff);
    this.Schedule();
  }

  private func Schedule() -> Void {
    let delay = GameInstance.GetDelaySystem(this.m_ctx.game);
    let request = new HotswapTick();
    request.generation = this.m_generation;
    delay.DelayScriptableSystemRequest(n"HotswapSystem", request, this.TickSeconds(), false);
    let callback = new HotswapTickCallback();
    callback.game = this.m_ctx.game;
    callback.generation = this.m_generation;
    delay.DelayCallback(callback, this.TickSeconds() * 1.5, false);
  }

  public func Tick(generation: Int32) -> Void {
    if !this.m_running || generation != this.m_generation {
      return;
    }
    this.m_generation += 1;
    this.m_lastTickAt = this.Now();
    this.Step();
    if this.m_running {
      this.Schedule();
    }
  }

  private func Enter(stage: HotswapStage) -> Void {
    this.m_stage = stage;
    this.m_waited = 0;
  }

  private func TimedOut() -> Bool {
    this.m_waited += 1;
    return this.m_waited >= this.WaitLimit();
  }

  private func Step() -> Void {
    switch this.m_stage {
      case HotswapStage.CyberOff:
        this.QueueCyberOff();
        this.Enter(HotswapStage.WaitCyberOff);
        break;
      case HotswapStage.WaitCyberOff:
        if this.AllCleared() {
          this.Enter(HotswapStage.Development);
        } else {
          if this.TimedOut() {
            this.Fail(HotswapText.GearStuck());
          }
        }
        break;
      case HotswapStage.Development:
        this.RunDevelopment();
        break;
      case HotswapStage.Settle:
        // Selling some perks moves gear by itself (HandleRemovingPerkLevel). Slot locks and stats
        // need a moment to catch up as well.
        this.m_waited += 1;
        if this.m_waited >= 3 {
          this.Enter(HotswapStage.CyberOn);
        }
        break;
      case HotswapStage.CyberOn:
        this.QueueCyberOn();
        this.Enter(HotswapStage.WaitCyberOn);
        break;
      case HotswapStage.WaitCyberOn:
        if this.CyberwareLanded() || this.TimedOut() {
          this.Enter(HotswapStage.PartsOff);
        }
        break;
      case HotswapStage.PartsOff:
        this.QueuePartsOff();
        this.Enter(HotswapStage.WaitPartsOff);
        break;
      case HotswapStage.WaitPartsOff:
        this.m_waited += 1;
        if this.m_waited >= 2 {
          this.Enter(HotswapStage.PartsOn);
        }
        break;
      case HotswapStage.PartsOn:
        this.QueuePartsOn();
        this.Enter(HotswapStage.WaitPartsOn);
        break;
      case HotswapStage.WaitPartsOn:
        if this.PartsLanded() || this.TimedOut() {
          this.Enter(HotswapStage.WeaponsOff);
        }
        break;
      case HotswapStage.WeaponsOff:
        this.QueueWeaponsOff();
        this.Enter(HotswapStage.WaitWeaponsOff);
        break;
      case HotswapStage.WaitWeaponsOff:
        if this.AllCleared() || this.TimedOut() {
          this.Enter(HotswapStage.WeaponsOn);
        }
        break;
      case HotswapStage.WeaponsOn:
        this.QueueWeaponsOn();
        this.Enter(HotswapStage.WaitWeaponsOn);
        break;
      case HotswapStage.WaitWeaponsOn:
        if this.WeaponsLanded() || this.TimedOut() {
          this.Enter(HotswapStage.Quick);
        }
        break;
      case HotswapStage.Quick:
        this.QueueQuick();
        this.Enter(HotswapStage.Finish);
        break;
      case HotswapStage.Finish:
        // One more tick lets the quick items land before they are read.
        this.m_waited += 1;
        if this.m_waited >= 2 {
          this.Finish();
        }
        break;
      default:
        break;
    }
  }

  // ---- Cyberware off ---------------------------------------------------------------------------

  // Capacity boosters come off last and go on first, so V is never over the limit between stages.
  private func QueueCyberOff() -> Void {
    ArrayClear(this.m_cleared);
    this.ClearOutgoing(false);
    this.ClearOutgoing(true);
    let arms = this.m_plan.WantAt(gamedataEquipmentArea.ArmsCW, 0);
    if IsDefined(arms) && !arms.missing
      && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, arms.area, arms.slot), arms.item)
      && HotswapGear.NeedsStyleCleared(this.m_ctx, arms.item) {
      HotswapGear.ClearArmStyle(this.m_ctx);
    }
  }

  private func ClearOutgoing(boosters: Bool) -> Void {
    for want in this.m_plan.gear {
      if HotswapNames.IsCyberwareArea(want.area) && !want.missing {
        this.ClearCyberware(want.area, want.slot, want.item, boosters);
      }
    }
  }

  private func ClearCyberware(area: gamedataEquipmentArea, slot: Int32, keep: ItemID, boosters: Bool) -> Void {
    // Eyes are never left empty. They stay on until something replaces them.
    if Equals(area, gamedataEquipmentArea.EyesCW) {
      return;
    }
    let raw = HotswapGear.Raw(this.m_ctx, area, slot);
    if !ItemID.IsValid(raw) || HotswapGear.Same(HotswapGear.Canon(this.m_ctx, area, raw), keep) {
      return;
    }
    if NotEquals(HotswapGear.IsBooster(this.m_ctx, raw), boosters) {
      return;
    }
    if HotswapGear.IsPinned(this.m_ctx, raw) {
      ArrayPush(this.m_problems, HotswapGear.DisplayName(this.m_ctx, raw));
      return;
    }
    HotswapGear.QueueUnequip(this.m_ctx, area, slot);
    ArrayPush(this.m_cleared, HotswapSlotRef.Make(area, slot));
  }

  private func AllCleared() -> Bool {
    for slot in this.m_cleared {
      if ItemID.IsValid(HotswapGear.Raw(this.m_ctx, slot.area, slot.slot)) {
        return false;
      }
    }
    return true;
  }

  // Kept cyberware can be what stops a capacity perk being sold. It comes off too, and the stages
  // after this put it back, parts included, because they compare the build with the live slots.
  private func StripEverything() -> Void {
    ArrayClear(this.m_cleared);
    let loadout = this.m_ctx.equip.GetEquipment();
    for pass in [false, true] {
      for area in loadout.equipAreas {
        if HotswapNames.IsCyberwareArea(area.areaType) {
          let slot = 0;
          let count = ArraySize(area.equipSlots);
          while slot < count {
            this.ClearCyberware(area.areaType, slot, ItemID.None(), pass);
            slot += 1;
          }
        }
      }
    }
  }

  // ---- Perks and attributes --------------------------------------------------------------------

  private func RunDevelopment() -> Void {
    if HotswapDevelopment.IsBlocked(this.m_ctx, this.m_plan) {
      if this.m_stripped {
        this.Fail(HotswapText.PerksStuck());
      } else {
        this.m_stripped = true;
        this.StripEverything();
        this.Enter(HotswapStage.WaitCyberOff);
      }
      return;
    }
    if !HotswapDevelopment.Run(this.m_ctx, this.m_plan, this.m_problems) {
      this.Fail(HotswapText.PerksStuck());
      return;
    }
    let after = HotswapTotals.Read(this.m_ctx);
    if !this.m_totals.Matches(after) {
      HSLog(s"Points moved. Before: \(this.m_totals.Describe()). After: \(after.Describe())");
      if !this.m_isUndo {
        this.Fail(HotswapText.PointsMoved());
        return;
      }
    }
    this.Enter(HotswapStage.Settle);
  }

  // ---- Cyberware on ----------------------------------------------------------------------------

  private func QueueCyberOn() -> Void {
    this.PlaceCyberware(true);
    this.PlaceCyberware(false);
  }

  private func PlaceCyberware(boosters: Bool) -> Void {
    for want in this.m_plan.gear {
      if HotswapNames.IsCyberwareArea(want.area) && !want.missing && ItemID.IsValid(want.item)
        && Equals(HotswapGear.IsBooster(this.m_ctx, want.item), boosters)
        && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item) {
        if HotswapGear.IsLocked(this.m_ctx, want.area, want.slot) {
          HSLog(s"Slot \(want.slot) of \(HotswapNames.OfArea(want.area)) is locked");
        } else {
          HotswapGear.QueueEquip(this.m_ctx, want.item, want.slot);
        }
      }
    }
  }

  private func CyberwareLanded() -> Bool {
    for want in this.m_plan.gear {
      if HotswapNames.IsCyberwareArea(want.area) && !want.missing && ItemID.IsValid(want.item)
        && !HotswapGear.IsLocked(this.m_ctx, want.area, want.slot)
        && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item) {
        return false;
      }
    }
    return true;
  }

  // ---- Parts -----------------------------------------------------------------------------------

  // A part in the wrong slot has to come off before it can go on again elsewhere, which is why this
  // is a separate stage from installing.
  private func QueuePartsOff() -> Void {
    let hosts: array<ItemID>;
    for want in this.m_plan.parts {
      if !ArrayContains(hosts, want.host) {
        ArrayPush(hosts, want.host);
      }
    }
    for host in hosts {
      let live = HotswapPlanner.LiveHost(this.m_ctx, this.m_plan, host);
      if ItemID.IsValid(live) {
        let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, live);
        for slot in slots {
          if Equals(slot.status, ESlotState.Taken)
            && HotswapGear.IsTrackedPart(slot.slotID, slot.innerItemData)
            && !this.KeepPart(host, slot.slotID, slot.installedPart) {
            HotswapGear.QueuePartRemoval(this.m_ctx, live, slot.slotID);
          }
        }
      }
    }
  }

  private func KeepPart(host: ItemID, attach: TweakDBID, installed: ItemID) -> Bool {
    for want in this.m_plan.parts {
      if HotswapGear.Same(want.host, host) && want.attach == attach {
        // Something missing from the build leaves the slot as it is, like gear does.
        return want.missing || ItemID.GetTDBID(want.part) == ItemID.GetTDBID(installed);
      }
    }
    return false;
  }

  private func QueuePartsOn() -> Void {
    let bag = HotswapBag.Of(this.m_ctx);
    for want in this.m_plan.parts {
      if !want.missing && !HotswapPlanner.PartIsOn(this.m_ctx, this.m_plan, want) {
        let live = HotswapPlanner.LiveHost(this.m_ctx, this.m_plan, want.host);
        let part = this.m_ctx.ts.HasItem(this.m_ctx.player, want.part)
          ? want.part
          : bag.FindRecord(ItemID.GetTDBID(want.part));
        if ItemID.IsValid(live) && ItemID.IsValid(part) {
          bag.Claim(part);
          HotswapGear.QueuePartInstall(this.m_ctx, live, part, want.attach);
        }
      }
    }
  }

  private func PartsLanded() -> Bool {
    for want in this.m_plan.parts {
      if !want.missing && !HotswapPlanner.PartIsOn(this.m_ctx, this.m_plan, want) {
        return false;
      }
    }
    return true;
  }

  // ---- Weapons ---------------------------------------------------------------------------------

  private func IsLeftSlot(slot: Int32) -> Bool {
    return slot >= EnumInt(WeaponSlot.LeftSlot_1) && slot <= EnumInt(WeaponSlot.LeftSlot_3);
  }

  private func IsWeaponDirty(slot: Int32) -> Bool {
    let want = this.m_plan.WantAt(gamedataEquipmentArea.Weapon, slot);
    return IsDefined(want) && !want.missing
      && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item);
  }

  // Taking off a right-hand weapon moves the left-hand one into its slot (UnequipItem). So if either
  // side of a pair has to change, the left comes off first and then the right, and they go back on
  // in the opposite order.
  private func QueueWeaponsOff() -> Void {
    ArrayClear(this.m_cleared);
    for want in this.m_plan.gear {
      if Equals(want.area, gamedataEquipmentArea.Weapon) && this.IsLeftSlot(want.slot) {
        let right = EquipmentSystemPlayerData.GetOppositeWeaponSlotIndex(want.slot);
        if this.IsWeaponDirty(want.slot) || this.IsWeaponDirty(right) {
          this.ClearWeapon(want.slot);
          this.ClearWeapon(right);
        }
      }
    }
    for want in this.m_plan.gear {
      if Equals(want.area, gamedataEquipmentArea.Weapon) && !this.IsLeftSlot(want.slot)
        && !this.IsCleared(want.slot) && this.IsWeaponDirty(want.slot) {
        this.ClearWeapon(want.slot);
      }
    }
  }

  private func IsCleared(slot: Int32) -> Bool {
    for cleared in this.m_cleared {
      if cleared.slot == slot {
        return true;
      }
    }
    return false;
  }

  private func ClearWeapon(slot: Int32) -> Void {
    if ItemID.IsValid(HotswapGear.Raw(this.m_ctx, gamedataEquipmentArea.Weapon, slot)) {
      HotswapGear.QueueUnequip(this.m_ctx, gamedataEquipmentArea.Weapon, slot);
      ArrayPush(this.m_cleared, HotswapSlotRef.Make(gamedataEquipmentArea.Weapon, slot));
    }
  }

  private func QueueWeaponsOn() -> Void {
    this.PlaceWeapons(false);
    this.PlaceWeapons(true);
  }

  private func PlaceWeapons(left: Bool) -> Void {
    for want in this.m_plan.gear {
      if Equals(want.area, gamedataEquipmentArea.Weapon) && !want.missing && ItemID.IsValid(want.item)
        && Equals(this.IsLeftSlot(want.slot), left)
        && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item) {
        if left && !this.CanDualWield(want) {
          ArrayPush(this.m_problems, HotswapGear.DisplayName(this.m_ctx, want.item));
        } else {
          HotswapGear.QueueWeapon(this.m_ctx, want.item, want.slot);
        }
      }
    }
  }

  private func CanDualWield(want: ref<HotswapWant>) -> Bool {
    let data = this.m_ctx.ItemData(want.item);
    return IsDefined(data) && data.CanDualWield(this.m_ctx.player);
  }

  private func WeaponsLanded() -> Bool {
    for want in this.m_plan.gear {
      if Equals(want.area, gamedataEquipmentArea.Weapon) && !want.missing && ItemID.IsValid(want.item)
        && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item) {
        if !this.IsLeftSlot(want.slot) || this.CanDualWield(want) {
          return false;
        }
      }
    }
    return true;
  }

  // ---- Quick items -----------------------------------------------------------------------------

  private func QueueQuick() -> Void {
    for want in this.m_plan.gear {
      if !want.missing && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item) {
        if Equals(want.area, gamedataEquipmentArea.CyberwareWheel) {
          HotswapGear.QueueWheel(this.m_ctx, want.item, want.slot);
        }
        if HotswapNames.IsQuickArea(want.area) {
          if ItemID.IsValid(want.item) {
            HotswapGear.QueueEquip(this.m_ctx, want.item, want.slot);
          } else {
            HotswapGear.QueueUnequip(this.m_ctx, want.area, want.slot);
          }
        }
      }
    }
    for hotkey in this.m_plan.hotkeys {
      if !HotswapGear.Same(this.m_ctx.equip.GetItemIDFromHotkey(hotkey.hotkey), hotkey.item) {
        HotswapGear.QueueHotkey(this.m_ctx, hotkey.item, hotkey.hotkey);
      }
    }
  }

  // ---- Finishing -------------------------------------------------------------------------------

  // Cyberware and attributes are the build. If those didn't land, V isn't wearing it and the swap is
  // undone. A quick item or one perk that didn't land is reported, and V keeps the rest.
  private func Finish() -> Void {
    let failed: array<String>;
    for want in this.m_plan.gear {
      if !want.missing && !HotswapGear.Same(HotswapGear.Current(this.m_ctx, want.area, want.slot), want.item) {
        let name = HotswapGear.DisplayName(this.m_ctx, want.item);
        if HotswapNames.IsCyberwareArea(want.area) && !HotswapGear.IsLocked(this.m_ctx, want.area, want.slot) {
          ArrayPush(failed, name);
        } else {
          if ItemID.IsValid(want.item) && !ArrayContains(this.m_problems, name) {
            ArrayPush(this.m_problems, name);
          }
        }
      }
    }
    for want in this.m_plan.attributes {
      if Cast<Int32>(this.m_ctx.dev.GetAttributeValue(want.stat)) != want.value {
        ArrayPush(failed, NameToString(HotswapNames.OfStat(want.stat)));
      }
    }
    if ArraySize(failed) > 0 && !this.m_isUndo {
      this.Fail(HotswapText.DidNotLand(failed));
      return;
    }

    if !this.m_isUndo {
      this.KeepResolvedItems();
      this.Charge();
    }

    let report = new HotswapReport();
    report.name = this.m_name;
    report.succeeded = !this.m_isUndo;
    report.rolledBack = this.m_isUndo;
    report.reason = this.m_reason;
    report.problems = this.m_problems;
    this.m_running = false;
    this.m_stage = HotswapStage.Idle;
    HSLog(s"Swap to \(this.m_name) finished. Undone: \(this.m_isUndo). Problems: \(ArraySize(this.m_problems)).");
    if IsDefined(this.m_sys) {
      this.m_sys.OnSwapFinished(report);
    }
  }

  // When an upgrade or a merged stack meant a row resolved to a different item, the build follows it.
  private func KeepResolvedItems() -> Void {
    for want in this.m_plan.gear {
      if IsDefined(want.entry) && !want.missing && ItemID.IsValid(want.item) {
        want.entry.item = want.item;
      }
    }
  }

  private func Charge() -> Void {
    let sys = this.m_sys;
    if IsDefined(sys) && sys.GetSettings().eddieCost > 0 {
      this.m_ctx.ts.RemoveItem(this.m_ctx.player, MarketSystem.Money(), sys.GetSettings().eddieCost);
    }
  }

  // Runs the same sequence again, towards what V was wearing when the swap began. Failing during
  // that just reports, because there is nothing further back to go to.
  private func Fail(reason: String) -> Void {
    HSLog(s"Swap to \(this.m_name) failed: \(reason)");
    if this.m_isUndo {
      ArrayPush(this.m_problems, reason);
      this.Finish();
      return;
    }
    let sys = this.m_sys;
    if !IsDefined(sys) {
      this.m_running = false;
      return;
    }
    this.m_reason = reason;
    this.m_isUndo = true;
    this.m_stripped = false;
    this.m_plan = HotswapPlanner.Make(this.m_ctx, sys, HotswapUndoBuild());
    this.Enter(HotswapStage.CyberOff);
  }
}
