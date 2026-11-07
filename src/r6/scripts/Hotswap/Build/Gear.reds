// Hotswap - reading and changing what sits in an equipment slot.
//
// Everything that touches a slot goes through here, so the game's unwritten rules live in one place.

public abstract class HotswapGear {

  // EquipItem and GetItemInEquipSlot both index with no bounds check, so an area or slot a build
  // remembers (say from Cyberware-EX, since removed) must be tested first.
  public static func SlotExists(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32) -> Bool {
    if ctx.equip.GetEquipAreaIndex(area) < 0 {
      return false;
    }
    return slot >= 0 && slot < ctx.equip.GetNumberOfSlots(area, true);
  }

  public static func Raw(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32) -> ItemID {
    if !HotswapGear.SlotExists(ctx, area, slot) {
      return ItemID.None();
    }
    return ctx.equip.GetItemInEquipSlot(area, slot);
  }

  // What a slot holds, seen the way a build sees it. A perk can replace a musculoskeletal item with a
  // generated copy (powerUpCyberwareEffector). The copy comes and goes with the perk, so a build
  // always talks about the original, and the two have to compare as the same thing.
  public static func Canon(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, item: ItemID) -> ItemID {
    if !ItemID.IsValid(item) || NotEquals(area, gamedataEquipmentArea.MusculoskeletalSystemCW) {
      return item;
    }
    let side: ref<Item_Record>;
    if RPGManager.CyberwareHasSideUpgrade(item, side) {
      return item;
    }
    let original = ctx.equip.GetOriginalItemIDFromSideUpgrade(item);
    return ItemID.IsValid(original) ? original : item;
  }

  public static func Current(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32) -> ItemID {
    return HotswapGear.Canon(ctx, area, HotswapGear.Raw(ctx, area, slot));
  }

  public static func Same(a: ItemID, b: ItemID) -> Bool {
    if !ItemID.IsValid(a) || !ItemID.IsValid(b) {
      return Equals(ItemID.IsValid(a), ItemID.IsValid(b));
    }
    return a == b;
  }

  public static func IsLocked(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32) -> Bool {
    let visible: Bool;
    return ctx.equip.IsSlotLocked(area, slot, visible);
  }

  public static func IsBooster(ctx: ref<HotswapContext>, item: ItemID) -> Bool {
    let data = ctx.ItemData(item);
    return IsDefined(data) && data.HasTag(n"CapacityBooster");
  }

  public static func IsPinned(ctx: ref<HotswapContext>, item: ItemID) -> Bool {
    let data = ctx.ItemData(item);
    return IsDefined(data) && data.HasTag(n"UnequipBlocked");
  }

  public static func Capacity(ctx: ref<HotswapContext>, item: ItemID) -> Float {
    let data = ctx.ItemData(item);
    return IsDefined(data) ? data.GetStatValueByType(gamedataStatType.HumanityAllocated) : 0.0;
  }

  public static func DisplayName(ctx: ref<HotswapContext>, item: ItemID) -> String {
    let record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
    if !IsDefined(record) {
      return "?";
    }
    return UIItemsHelper.GetItemName(record, ctx.ItemData(item));
  }

  private static func Send(ctx: ref<HotswapContext>, request: ref<ScriptableSystemRequest>) -> Void {
    GameInstance.GetScriptableSystemsContainer(ctx.game).Get(n"EquipmentSystem").QueueRequest(request);
  }

  public static func QueueUnequip(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32) -> Void {
    let request = new UnequipRequest();
    request.owner = ctx.player;
    request.areaType = area;
    request.slotIndex = slot;
    HotswapGear.Send(ctx, request);
  }

  // addToInventory stays false. With it set the game hands out a free copy of anything V doesn't own.
  public static func QueueEquip(ctx: ref<HotswapContext>, item: ItemID, slot: Int32) -> Void {
    let request = new EquipRequest();
    request.owner = ctx.player;
    request.itemID = item;
    request.slotIndex = slot;
    request.addToInventory = false;
    HotswapGear.Send(ctx, request);
  }

  // EquipRequest forces a weapon into V's hands (OnEquipRequest passes forceEquipWeapon = true). This
  // request can say no to that, so restoring a build doesn't draw every gun in it.
  public static func QueueWeapon(ctx: ref<HotswapContext>, item: ItemID, slot: Int32) -> Void {
    let request = new GameplayEquipRequest();
    request.owner = ctx.player;
    request.itemID = item;
    request.slotIndex = slot;
    request.addToInventory = false;
    request.blockUpdateWeaponActiveSlots = true;
    request.forceEquipWeapon = false;
    HotswapGear.Send(ctx, request);
  }

  public static func QueueWheel(ctx: ref<HotswapContext>, item: ItemID, slot: Int32) -> Void {
    let request = new AssignToCyberwareWheelRequest();
    request.owner = ctx.player;
    request.itemID = item;
    request.slotIndex = slot;
    HotswapGear.Send(ctx, request);
  }

  public static func QueueHotkey(ctx: ref<HotswapContext>, item: ItemID, hotkey: EHotkey) -> Void {
    let request = HotkeyAssignmentRequest.Construct(item, hotkey, ctx.player, EHotkeyRequestType.Assign);
    HotswapGear.Send(ctx, request);
  }

  public static func QueuePartRemoval(ctx: ref<HotswapContext>, host: ItemID, attach: TweakDBID) -> Void {
    let request = new RemoveItemPart();
    request.Set(ctx.player, host, attach);
    GameInstance.GetScriptableSystemsContainer(ctx.game).Get(n"ItemModificationSystem").QueueRequest(request);
  }

  public static func QueuePartInstall(ctx: ref<HotswapContext>, host: ItemID, part: ItemID, attach: TweakDBID) -> Void {
    let request = new InstallItemPart();
    request.Set(ctx.player, host, part, attach);
    GameInstance.GetScriptableSystemsContainer(ctx.game).Get(n"ItemModificationSystem").QueueRequest(request);
  }

  // The parts a build tracks are the ones the game strips when cyberware comes off. Stat shards and
  // dummy parts stay on the item either way (UnequipCyberwareParts), so they are not ours to move.
  public static func IsTrackedPart(attach: TweakDBID, data: InnerItemData) -> Bool {
    if attach == t"AttachmentSlots.StatsShardSlot" {
      return false;
    }
    let record = InnerItemData.GetStaticData(data);
    return !IsDefined(record) || !record.TagsContains(n"DummyPart");
  }

  // Changing arms to a different kind leaves the old cosmetic style on them. The ripperdoc clears
  // it from its own screen, so with the screen bypassed the job falls to us.
  public static func NeedsStyleCleared(ctx: ref<HotswapContext>, incoming: ItemID) -> Bool {
    if !ItemID.IsValid(ctx.equip.GetActiveItem(gamedataEquipmentArea.ArmsCWStyle)) {
      return false;
    }
    let outgoing = ctx.equip.GetActiveItem(gamedataEquipmentArea.ArmsCW);
    if !ItemID.IsValid(outgoing) || !ItemID.IsValid(incoming) {
      return ItemID.IsValid(outgoing);
    }
    return NotEquals(RPGManager.GetItemType(outgoing), RPGManager.GetItemType(incoming));
  }

  public static func ClearArmStyle(ctx: ref<HotswapContext>) -> Void {
    let container = GameInstance.GetScriptableSystemsContainer(ctx.game);
    let customization = container.Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(customization) {
      let saved = customization.GetSavedData();
      let request = new SaveAndApplyCyberwareCustomizationDataRequest();
      request.enabled = false;
      request.switcherName = saved.switcherName;
      request.switcherIndex = 0u;
      customization.QueueRequest(request);
    }
    HotswapGear.QueueUnequip(ctx, gamedataEquipmentArea.ArmsCWStyle, 0);
  }
}

// Everything V owns right now, plus which items this pass has already spoken for. A fuzzy match
// must not hand the same item to two slots.
public class HotswapBag {
  public let items: array<wref<gameItemData>>;
  public let claimed: array<ItemID>;

  public static func Of(ctx: ref<HotswapContext>) -> ref<HotswapBag> {
    let self = new HotswapBag();
    let list: array<wref<gameItemData>>;
    ctx.ts.GetItemList(ctx.player, list);
    self.items = list;
    return self;
  }

  public func IsClaimed(item: ItemID) -> Bool {
    return ArrayContains(this.claimed, item);
  }

  public func Claim(item: ItemID) -> Void {
    if ItemID.IsValid(item) && !this.IsClaimed(item) {
      ArrayPush(this.claimed, item);
    }
  }

  public func FindRecord(record: TweakDBID) -> ItemID {
    for data in this.items {
      if IsDefined(data) {
        let id = data.GetID();
        if ItemID.GetTDBID(id) == record && !this.IsClaimed(id) {
          return id;
        }
      }
    }
    return ItemID.None();
  }

  // Upgrading cyberware creates a new item and removes the old, so a build saved earlier names
  // something that no longer exists. The record chain leads from the old item to the new one, and
  // walking it also covers upgrades made while Hotswap was not installed.
  public func FindUpgrade(stored: ItemID) -> ItemID {
    let record: wref<Item_Record> = RPGManager.GetItemRecord(stored);
    let steps = 0;
    while IsDefined(record) && steps < 8 {
      let next: wref<Item_Record> = record.NextUpgradeItem();
      if !IsDefined(next) || !TDBID.IsValid(next.GetID()) {
        return ItemID.None();
      }
      let found = this.FindRecord(next.GetID());
      if ItemID.IsValid(found) {
        return found;
      }
      record = next;
      steps += 1;
    }
    return ItemID.None();
  }

  // The item a build means, if V still has it. The same record is accepted as a last resort, which
  // is what makes stackable items and quickhacks work: their seeds change as stacks merge.
  public func Resolve(ctx: ref<HotswapContext>, stored: ItemID) -> ItemID {
    if !ItemID.IsValid(stored) {
      return ItemID.None();
    }
    if ctx.ts.HasItem(ctx.player, stored) && !this.IsClaimed(stored) {
      this.Claim(stored);
      return stored;
    }
    let found = this.FindUpgrade(stored);
    if !ItemID.IsValid(found) {
      found = this.FindRecord(ItemID.GetTDBID(stored));
    }
    this.Claim(found);
    return found;
  }
}
