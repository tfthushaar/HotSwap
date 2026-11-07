// Hotswap - writing down what V is wearing right now.

public abstract class HotswapCapture {

  public static func Into(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32) -> Void {
    sys.ClearEntries(build);
    HotswapCapture.Gear(ctx, sys, build);
    HotswapCapture.Hotkey(ctx, sys, build, EHotkey.RB, n"RB");
    HotswapCapture.Hotkey(ctx, sys, build, EHotkey.DPAD_UP, n"DPAD_UP");
    HotswapCapture.Perks(ctx, sys, build);
    HotswapCapture.Attributes(ctx, sys, build);
  }

  // GetEquipment lists the areas V really has, however many slots a mod has added to them. An empty
  // slot gets a row too: it is what lets a build mean "nothing here" and not "leave this alone".
  private static func Gear(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32) -> Void {
    let loadout = ctx.equip.GetEquipment();
    for area in loadout.equipAreas {
      if HotswapNames.IsBuildArea(area.areaType) {
        let slot = 0;
        let count = ArraySize(area.equipSlots);
        while slot < count {
          let live = area.equipSlots[slot].itemID;
          let item = HotswapGear.Canon(ctx, area.areaType, live);
          sys.AddEntry(build, HotswapKindGear(), HotswapNames.OfArea(area.areaType), slot, item);
          if ItemID.IsValid(item) && HotswapNames.IsCyberwareArea(area.areaType) {
            HotswapCapture.Parts(ctx, sys, build, live, item);
          }
          slot += 1;
        }
      }
    }
  }

  // live is the item in the slot, which may be a generated copy. The parts are read from that, and
  // stored against the item the build names.
  public static func Parts(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32, live: ItemID, named: ItemID) -> Void {
    let slots = ItemModificationSystem.GetAllSlots(ctx.player, live);
    for slot in slots {
      if Equals(slot.status, ESlotState.Taken) && HotswapGear.IsTrackedPart(slot.slotID, slot.innerItemData) {
        sys.AddPart(build, named, slot.slotID, slot.installedPart);
      }
    }
  }

  private static func Hotkey(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32, hotkey: EHotkey, name: CName) -> Void {
    let item = ctx.equip.GetItemIDFromHotkey(hotkey);
    if ItemID.IsValid(item) {
      sys.AddEntry(build, HotswapKindHotkey(), name, 0, item);
    }
  }

  // Only perks with levels get a row. A build means "these perks, and no others".
  private static func Perks(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32) -> Void {
    let i = 0;
    let count = HotswapNames.PerkCount();
    while i < count {
      let perk = HotswapNames.PerkAt(i);
      let level = ctx.dev.IsNewPerkBought(perk);
      if level > 0 {
        sys.AddEntry(build, HotswapKindPerk(), HotswapNames.OfPerk(perk), level, ItemID.None());
      }
      i += 1;
    }
  }

  private static func Attributes(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, build: Int32) -> Void {
    for stat in HotswapNames.Attributes() {
      let value = Cast<Int32>(ctx.dev.GetAttributeValue(stat));
      sys.AddEntry(build, HotswapKindAttribute(), HotswapNames.OfStat(stat), value, ItemID.None());
    }
  }
}
