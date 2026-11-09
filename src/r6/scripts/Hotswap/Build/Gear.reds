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

  // With Tech_Central_Milestone_3 at level 3 the game replaces each skeleton item with the copy its
  // record names as sideUpgradeItem, and puts the original back in the inventory
  // (PowerUpCyberwareEffector). The copy comes and goes with the perk, so a build always names the
  // original, and nothing here may compare the two by ID.
  //
  // The record is the link between them. GetOriginalItemIDFromSideUpgrade isn't used, because it goes
  // by tags, quality, cyberware type and stat shard, which is a resemblance and not a link.
  private static func IsCopyOf(copy: ItemID, original: ItemID) -> Bool {
    let side: ref<Item_Record>;
    return RPGManager.CyberwareHasSideUpgrade(original, side) && side.GetID() == ItemID.GetTDBID(copy);
  }

  // The item a build should name, given one that may be a copy.
  public static func Canon(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, item: ItemID) -> ItemID {
    if !ItemID.IsValid(item) || NotEquals(area, gamedataEquipmentArea.MusculoskeletalSystemCW) {
      return item;
    }
    let side: ref<Item_Record>;
    if RPGManager.CyberwareHasSideUpgrade(item, side) {
      return item;
    }
    let list: array<wref<gameItemData>>;
    ctx.ts.GetItemList(ctx.player, list);
    for data in list {
      if IsDefined(data) && HotswapGear.IsCopyOf(item, data.GetID()) {
        return data.GetID();
      }
    }
    return item;
  }

  // Whether a slot holds what a build wants there, which an invalid item means is nothing. This is the
  // only comparison of a slot with a build. Everything that asks goes through here, so nothing can
  // disagree about what V is wearing.
  public static func Holds(ctx: ref<HotswapContext>, area: gamedataEquipmentArea, slot: Int32, item: ItemID) -> Bool {
    let raw = HotswapGear.Raw(ctx, area, slot);
    if HotswapGear.Same(raw, item) {
      return true;
    }
    if !ItemID.IsValid(raw) || !ItemID.IsValid(item) || NotEquals(area, gamedataEquipmentArea.MusculoskeletalSystemCW) {
      return false;
    }
    return HotswapGear.IsCopyOf(raw, item) || HotswapGear.IsCopyOf(item, raw);
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

  // On a weapon, the parts a build tracks are its scope, its muzzle and its mods: the slots the game
  // itself lists as attachments and mods for that kind of weapon (RPGManager). A weapon's receiver,
  // barrel and magazine are the weapon, and an iconic's own mod can't be moved.
  //
  // On cyberware they are the ones the game strips when it comes off. Stat shards and dummy parts stay
  // on the item either way (UnequipCyberwareParts), so they are not ours to move.
  public static func IsTrackedPart(host: ItemID, attach: TweakDBID, data: InnerItemData) -> Bool {
    if RPGManager.IsItemWeapon(host) {
      return HotswapGear.IsWeaponModSlot(host, attach);
    }
    if attach == t"AttachmentSlots.StatsShardSlot" {
      return false;
    }
    let record = InnerItemData.GetStaticData(data);
    return !IsDefined(record) || !record.TagsContains(n"DummyPart");
  }

  public static func IsWeaponModSlot(weapon: ItemID, attach: TweakDBID) -> Bool {
    if attach == t"AttachmentSlots.Scope" || attach == t"AttachmentSlots.PowerModule" {
      return true;
    }
    // Stored first: an array intrinsic must never be handed a function's result (see
    // tools/check_array_arguments.ps1).
    let mods = RPGManager.GetModsSlotIDs(RPGManager.GetItemType(weapon));
    return ArrayContains(mods, attach);
  }

  // Changing arms to a different kind leaves the old cosmetic style on them. The ripperdoc clears
  // it from its own screen, so with the screen bypassed the job falls to us. Arm styles came with
  // 2.5, so on 2.31 there is never one to clear (HotswapPatch).
  public static func NeedsStyleCleared(ctx: ref<HotswapContext>, incoming: ItemID) -> Bool {
    let style = HotswapPatch.ArmStyleArea();
    if Equals(style, gamedataEquipmentArea.Invalid) || !ItemID.IsValid(ctx.equip.GetActiveItem(style)) {
      return false;
    }
    let outgoing = ctx.equip.GetActiveItem(gamedataEquipmentArea.ArmsCW);
    if !ItemID.IsValid(outgoing) || !ItemID.IsValid(incoming) {
      return ItemID.IsValid(outgoing);
    }
    return NotEquals(RPGManager.GetItemType(outgoing), RPGManager.GetItemType(incoming));
  }

  public static func ClearArmStyle(ctx: ref<HotswapContext>) -> Void {
    let style = HotswapPatch.ArmStyleArea();
    if Equals(style, gamedataEquipmentArea.Invalid) {
      return;
    }
    HotswapPatch.SwitchOffArmStyle(ctx.game);
    HotswapGear.QueueUnequip(ctx, style, 0);
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
