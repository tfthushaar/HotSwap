// Hotswap - running a swap.
//
// A build changes in the order a respec takes: every piece of cyberware comes off, every perk and
// attribute point is reset, attributes are assigned, then perks, then cyberware goes back on, then
// weapon mods, weapons and quick items. Each step meets the needs of the next. With nothing equipped
// no perk is held in place by the cyberware using it, and capacity is only checked once the perks
// that set it are final, which is when EquipItem checks it (HumanityAllocationPrereq).
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
    HotswapPlanner.KeepUnlisted(ctx, plan);
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

  // A swap that changes neither cyberware nor perks leaves cyberware alone. Anything else takes all of
  // it off first. Capacity boosters come off last, so V is never over the limit on the way down.
  private func QueueCyberOff() -> Void {
    ArrayClear(this.m_cleared);
    if this.m_plan.changedCyberware == 0 && !this.m_plan.ChangesDevelopment() {
      return;
    }
    let arms = this.m_plan.WantAt(gamedataEquipmentArea.ArmsCW, 0);
    if IsDefined(arms) && !arms.missing
      && !HotswapGear.Holds(this.m_ctx, arms.area, arms.slot, arms.item)
      && HotswapGear.NeedsStyleCleared(this.m_ctx, arms.item) {
      HotswapGear.ClearArmStyle(this.m_ctx);
    }
    this.StripEverything();
    HSLog(s"Taking off \(ArraySize(this.m_cleared)) pieces of cyberware");
  }

  // Eyes stay: V can't be without them, and new ones replace the old in one step. An item the game
  // pins in place stays too, and is only a problem if the build wants something else there.
  private func StripEverything() -> Void {
    let loadout = this.m_ctx.equip.GetEquipment();
    for boosters in [false, true] {
      for area in loadout.equipAreas {
        if HotswapNames.IsCyberwareArea(area.areaType) && NotEquals(area.areaType, gamedataEquipmentArea.EyesCW) {
          let slot = 0;
          let count = ArraySize(area.equipSlots);
          while slot < count {
            let raw = HotswapGear.Raw(this.m_ctx, area.areaType, slot);
            if ItemID.IsValid(raw) && Equals(HotswapGear.IsBooster(this.m_ctx, raw), boosters) {
              if HotswapGear.IsPinned(this.m_ctx, raw) {
                let want = this.m_plan.WantAt(area.areaType, slot);
                if IsDefined(want) && !want.missing && !HotswapGear.Holds(this.m_ctx, area.areaType, slot, want.item) {
                  ArrayPush(this.m_problems, HotswapGear.DisplayName(this.m_ctx, raw));
                }
              } else {
                HotswapGear.QueueUnequip(this.m_ctx, area.areaType, slot);
                ArrayPush(this.m_cleared, HotswapSlotRef.Make(area.areaType, slot));
              }
            }
            slot += 1;
          }
        }
      }
    }
  }

  private func AllCleared() -> Bool {
    for slot in this.m_cleared {
      if ItemID.IsValid(HotswapGear.Raw(this.m_ctx, slot.area, slot.slot)) {
        return false;
      }
    }
    return true;
  }

  // ---- Perks and attributes --------------------------------------------------------------------

  private func RunDevelopment() -> Void {
    let result = HotswapDevelopment.Run(this.m_ctx, this.m_plan, this.m_problems);
    if NotEquals(result, HotswapDevelopmentResult.Done) {
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
    if this.m_plan.ChangesDevelopment() {
      HSLog(s"Perks and attributes set. \(after.Describe())");
    }
    this.Enter(HotswapStage.Settle);
  }

  // ---- Cyberware on ----------------------------------------------------------------------------

  // Capacity boosters go on first, then eyes, while V has the most room, then everything else.
  private func QueueCyberOn() -> Void {
    let phase = 0;
    while phase < 3 {
      this.PlaceCyberware(phase);
      phase += 1;
    }
  }

  private func Phase(want: ref<HotswapWant>) -> Int32 {
    if HotswapGear.IsBooster(this.m_ctx, want.item) {
      return 0;
    }
    return Equals(want.area, gamedataEquipmentArea.EyesCW) ? 1 : 2;
  }

  private func PlaceCyberware(phase: Int32) -> Void {
    for want in this.m_plan.gear {
      if HotswapNames.IsCyberwareArea(want.area) && !want.missing && ItemID.IsValid(want.item)
        && this.Phase(want) == phase
        && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item) {
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
        && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item) {
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
            && HotswapGear.IsTrackedPart(live, slot.slotID, slot.innerItemData)
            && !this.KeepPart(host, slot.slotID, slot.installedPart) {
            HotswapGear.QueuePartRemoval(this.m_ctx, live, slot.slotID);
          }
        }
      }
    }
    this.FreeHeldParts();
  }

  // A weapon mod the build wants can be on one of V's weapons that the build doesn't use. It comes off
  // there first, or it would never be free to go on.
  private func FreeHeldParts() -> Void {
    let list: array<wref<gameItemData>>;
    this.m_ctx.ts.GetItemList(this.m_ctx.player, list);
    for want in this.m_plan.parts {
      if !want.missing && RPGManager.IsItemWeapon(want.host)
        && !this.m_ctx.ts.HasItem(this.m_ctx.player, want.part)
        && !HotswapPlanner.PartIsOn(this.m_ctx, this.m_plan, want) {
        for data in list {
          let holder = IsDefined(data) ? data.GetID() : ItemID.None();
          if RPGManager.IsItemWeapon(holder) && !HotswapGear.Same(holder, want.host) {
            let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, holder);
            for slot in slots {
              if Equals(slot.status, ESlotState.Taken) && slot.installedPart == want.part {
                HotswapGear.QueuePartRemoval(this.m_ctx, holder, slot.slotID);
              }
            }
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
      && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item);
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
        && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item) {
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
        && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item) {
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
      if !want.missing && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item) {
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
      if !want.missing && !HotswapGear.Holds(this.m_ctx, want.area, want.slot, want.item) {
        let raw = HotswapGear.Raw(this.m_ctx, want.area, want.slot);
        let name = HotswapGear.DisplayName(this.m_ctx, ItemID.IsValid(want.item) ? want.item : raw);
        HSLog(s"Slot \(want.slot) of \(HotswapNames.OfArea(want.area)) holds \(TDBID.ToStringDEBUG(ItemID.GetTDBID(raw))), wanted \(TDBID.ToStringDEBUG(ItemID.GetTDBID(want.item)))");
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
    if ArraySize(failed) > 0 {
      if !this.m_isUndo {
        this.Fail(HotswapText.DidNotLand(failed));
        return;
      }
      // There is nothing further back to go to, so what didn't come back is what gets reported.
      for name in failed {
        if !ArrayContains(this.m_problems, name) {
          ArrayPush(this.m_problems, name);
        }
      }
    }

    if !this.m_isUndo {
      this.KeepResolvedItems();
      if !this.m_plan.free {
        this.Charge();
      }
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
    // From here on, problems are what the undo couldn't restore.
    ArrayClear(this.m_problems);
    this.m_plan = HotswapPlanner.Make(this.m_ctx, sys, HotswapUndoBuild());
    HotswapPlanner.KeepUnlisted(this.m_ctx, this.m_plan);
    this.Enter(HotswapStage.CyberOff);
  }
}
