// Hotswap - what differs between the game patches Hotswap runs on, 2.31 and 2.5.
//
// Patch 2.5 added dual wielding (three left-hand weapon slots, the Double Trouble perk and four more
// Cool perks) and Glamdoc arm styles (a style slot for arm cyberware, and the system that applies
// it). Naming any of those in a script stops every script mod from compiling on 2.31, so they are
// looked up by name while the game runs. On 2.5 each lookup lands on the game's own value or
// function, and Hotswap does exactly what it did when it named them. On 2.31 nothing is found, and
// Hotswap treats the game as having no left hand and no arm styles, which is what 2.31 is.
//
// The five new perks need nothing here: perks are stored and judged by name (HotswapNames), so on
// 2.31 their names simply never come up.
//
// Lookups go through Codeware's Reflection, which answers null for a name the game doesn't have.
// A call through it only runs when every argument has exactly the type the game function declares,
// so each argument below is held in a variable of that type first.

public abstract class HotswapPatch {

  // ---- Dual wielding (2.5) -----------------------------------------------------------------------

  // WeaponSlot.LeftSlot_1 to LeftSlot_3 on 2.5, which the equipment system keeps as weapon slots 3
  // to 5. 2.31 has no WeaponSlot, so no slot is a left-hand one there.
  public static func IsLeftWeaponSlot(slot: Int32) -> Bool {
    let first = HotswapPatch.WeaponSlot(n"LeftSlot_1");
    let last = HotswapPatch.WeaponSlot(n"LeftSlot_3");
    return first >= 0 && last >= 0 && slot >= first && slot <= last;
  }

  public static func LeftWeaponSlots() -> array<Int32> {
    let names: array<CName> = [n"LeftSlot_1", n"LeftSlot_2", n"LeftSlot_3"];
    let slots: array<Int32>;
    for name in names {
      let slot = HotswapPatch.WeaponSlot(name);
      if slot >= 0 {
        ArrayPush(slots, slot);
      }
    }
    return slots;
  }

  // The right-hand slot a left-hand slot pairs with, from the game's own
  // EquipmentSystemPlayerData.GetOppositeWeaponSlotIndex. -1 when the game has no such pairing.
  public static func OppositeWeaponSlot(slot: Int32) -> Int32 {
    let owner = Reflection.GetClass(n"EquipmentSystemPlayerData");
    if !IsDefined(owner) {
      return -1;
    }
    let opposite = owner.GetStaticFunction(n"GetOppositeWeaponSlotIndex");
    if !IsDefined(opposite) {
      return -1;
    }
    let args: array<Variant>;
    ArrayPush(args, ToVariant(slot));
    let ok = false;
    let result = opposite.Call(args, ok);
    if !ok {
      HSLog(s"Couldn't ask the game which slot pairs with weapon slot \(slot)");
      return -1;
    }
    return FromVariant<Int32>(result);
  }

  // The game's own gameItemData.CanDualWield: a dual wield weapon, the Double Trouble perk, and no
  // quest holding it back. False on 2.31, which has none of that.
  public static func CanDualWield(data: wref<gameItemData>, owner: wref<GameObject>) -> Bool {
    let item: ref<gameItemData> = data;
    if !IsDefined(item) {
      return false;
    }
    let type = Reflection.GetClass(n"gameItemData");
    if !IsDefined(type) {
      return false;
    }
    let check = type.GetFunction(n"CanDualWield");
    if !IsDefined(check) {
      return false;
    }
    let args: array<Variant>;
    ArrayPush(args, ToVariant(owner));
    let ok = false;
    let result = check.Call(item, args, ok);
    if !ok {
      HSLog("Couldn't ask the game whether a weapon can be dual wielded");
      return false;
    }
    return FromVariant<Bool>(result);
  }

  private static func WeaponSlot(name: CName) -> Int32 {
    let slots = Reflection.GetEnum(n"WeaponSlot");
    if !IsDefined(slots) {
      return -1;
    }
    let constants = slots.GetConstants();
    for constant in constants {
      if Equals(constant.GetName(), name) {
        return Cast<Int32>(constant.GetValue());
      }
    }
    return -1;
  }

  // ---- Arm styles (2.5) --------------------------------------------------------------------------
  //
  // The Glamdoc gives V one look for arm cyberware at a time. It is two things: a style item from
  // V's inventory (a cosmetic such as MilitechStrongArmsCosmetic) in the ArmsCWStyle slot, and what
  // CyberwareCustomizationSystem has saved: whether the look is on, the style's switcher name and
  // index, and two colour indexes into the style's brand palette. The Glamdoc changes both together:
  // an EquipRequest or UnequipRequest for the slot, and a SaveAndApplyCyberwareCustomizationData
  // request for the rest (glamdoc.script, SendLatestToCyberwareCustomization and
  // UnequipCyberwareCustomization). Hotswap does the same, in the same two halves.

  // The equipment area that holds the Glamdoc style of V's arm cyberware. Invalid on 2.31.
  public static func ArmStyleArea() -> gamedataEquipmentArea {
    return HotswapNames.ToArea(n"ArmsCWStyle");
  }

  public static func HasArmStyles() -> Bool {
    return NotEquals(HotswapPatch.ArmStyleArea(), gamedataEquipmentArea.Invalid);
  }

  // V's arm style now: the style item in its slot, and the colours and switch the system has saved.
  // Null on 2.31, or if the saved data can't be read, which a build then takes as "leave it alone".
  public static func ReadArmStyle(ctx: ref<HotswapContext>) -> ref<HotswapArmStyle> {
    let area = HotswapPatch.ArmStyleArea();
    if Equals(area, gamedataEquipmentArea.Invalid) {
      return null;
    }
    let saved = HotswapPatch.SavedArmStyle(ctx.game);
    let savedType = Reflection.GetClass(n"CyberwareCustomizationPersistentData");
    if !IsDefined(saved) || !IsDefined(savedType) {
      return null;
    }
    let enabled = savedType.GetProperty(n"enabled");
    let primary = savedType.GetProperty(n"primaryColorIndex");
    let secondary = savedType.GetProperty(n"secondaryColorIndex");
    if !IsDefined(enabled) || !IsDefined(primary) || !IsDefined(secondary) {
      return null;
    }
    let style = new HotswapArmStyle();
    style.item = HotswapGear.Raw(ctx, area, 0);
    // With no style on, the colours left in the saved data mean nothing, so they aren't kept.
    if ItemID.IsValid(style.item) {
      style.enabled = FromVariant<Bool>(enabled.GetValue(saved));
      style.primary = Cast<Int32>(FromVariant<Uint8>(primary.GetValue(saved)));
      style.secondary = Cast<Int32>(FromVariant<Uint8>(secondary.GetValue(saved)));
    }
    return style;
  }

  // The Glamdoc's own rule for which arms a style is for (ItemTagToIndex and CheckIfCanApply): the
  // style's first tag of ProjectileLauncher, MantisBlades, NanoWires and StrongArms, against the
  // arms' item type.
  public static func StyleFits(ctx: ref<HotswapContext>, style: ItemID, arms: ItemID) -> Bool {
    let data = ctx.ItemData(style);
    if !IsDefined(data) || !ItemID.IsValid(arms) {
      return false;
    }
    let tag: CName;
    if data.HasTag(n"ProjectileLauncher") {
      tag = n"ProjectileLauncher";
    } else {
      if data.HasTag(n"MantisBlades") {
        tag = n"MantisBlades";
      } else {
        if data.HasTag(n"NanoWires") {
          tag = n"NanoWires";
        } else {
          if data.HasTag(n"StrongArms") {
            tag = n"StrongArms";
          } else {
            return false;
          }
        }
      }
    }
    switch RPGManager.GetItemType(arms) {
      case gamedataItemType.Cyb_Launcher:
        return Equals(tag, n"ProjectileLauncher");
      case gamedataItemType.Cyb_MantisBlades:
        return Equals(tag, n"MantisBlades");
      case gamedataItemType.Cyb_NanoWires:
        return Equals(tag, n"NanoWires");
      case gamedataItemType.Cyb_StrongArms:
        return Equals(tag, n"StrongArms");
      default:
        return false;
    }
  }

  // Sends the look half of a style, as the Glamdoc does when it applies one
  // (SendLatestToCyberwareCustomization): the style item, the arms its record is for, its look for
  // long sleeves when V wears them and its usual look otherwise, and the colours. The style item goes
  // in its slot separately, with an EquipRequest, as the Glamdoc does too.
  public static func ApplyArmStyle(ctx: ref<HotswapContext>, style: ref<HotswapArmStyle>) -> Bool {
    let data: ref<gameItemData> = ctx.ItemData(style.item);
    // A style's record is a UIGlamdocCustomizationItem_Record, which extends Item_Record, so the item
    // lookup returns it, and its real class has the Glamdoc fields (CallRecord).
    let record: ref<TweakDBRecord> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(style.item));
    if !IsDefined(data) || !IsDefined(record) {
      return false;
    }
    let armType = HotswapPatch.CallRecord(record, n"CyberarmType");
    let usualLook = HotswapPatch.CallRecord(record, n"CustomizationIndex");
    let sleevesLook = HotswapPatch.CallRecord(record, n"LongSleevesCustomizationIndex");
    if !IsDefined(armType) || !IsDefined(usualLook) || !IsDefined(sleevesLook) {
      HSLog("The arm style's record couldn't be read, so the arm style stays as it is");
      return false;
    }
    let switcherName = FromVariant<CName>(armType);
    let usual = FromVariant<Int32>(usualLook);
    let sleeves = FromVariant<Int32>(sleevesLook);
    let index = sleeves != -1 && HotswapPatch.HasLongSleeves(ctx) ? sleeves : usual;
    if Equals(switcherName, n"") || index < 0 {
      HSLog("The arm style's record has no arm type or look, so the arm style stays as it is");
      return false;
    }
    let enabled = style.enabled;
    let switcherIndex: Uint32 = Cast<Uint32>(index);
    let primary: Uint8 = Cast<Uint8>(style.primary);
    let secondary: Uint8 = Cast<Uint8>(style.secondary);
    let values: array<CName> = [n"enabled", n"customizationItem", n"switcherName", n"switcherIndex", n"primaryColorIndex", n"secondaryColorIndex"];
    let settings: array<Variant>;
    ArrayPush(settings, ToVariant(enabled));
    ArrayPush(settings, ToVariant(data));
    ArrayPush(settings, ToVariant(switcherName));
    ArrayPush(settings, ToVariant(switcherIndex));
    ArrayPush(settings, ToVariant(primary));
    ArrayPush(settings, ToVariant(secondary));
    return HotswapPatch.SendArmStyle(ctx.game, values, settings);
  }

  // Switches the arm style off the way the Glamdoc and the ripperdoc do (UnequipCyberwareCustomization,
  // UnequipCyberwareStyle): enabled false, switcher index 0, and the switcher name the system has
  // saved, since the request's name is what the system saves next. Does nothing on 2.31.
  public static func SwitchOffArmStyle(game: GameInstance) -> Void {
    let saved = HotswapPatch.SavedArmStyle(game);
    let savedType = Reflection.GetClass(n"CyberwareCustomizationPersistentData");
    if !IsDefined(saved) || !IsDefined(savedType) {
      return;
    }
    let savedName = savedType.GetProperty(n"switcherName");
    if !IsDefined(savedName) {
      return;
    }
    let off = false;
    let name: CName = FromVariant<CName>(savedName.GetValue(saved));
    let first: Uint32 = 0u;
    let values: array<CName> = [n"enabled", n"switcherName", n"switcherIndex"];
    let settings: array<Variant>;
    ArrayPush(settings, ToVariant(off));
    ArrayPush(settings, ToVariant(name));
    ArrayPush(settings, ToVariant(first));
    HotswapPatch.SendArmStyle(game, values, settings);
  }

  // CyberwareCustomizationSystem.GetSavedData, as a Variant holding the struct. Empty on 2.31.
  private static func SavedArmStyle(game: GameInstance) -> Variant {
    let empty: Variant;
    let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem");
    let systemType = Reflection.GetClass(n"CyberwareCustomizationSystem");
    if !IsDefined(system) || !IsDefined(systemType) {
      return empty;
    }
    let getSaved = systemType.GetFunction(n"GetSavedData");
    if !IsDefined(getSaved) {
      return empty;
    }
    let noArgs: array<Variant>;
    let read = false;
    let saved = getSaved.Call(system, noArgs, read);
    if !read {
      HSLog("Couldn't read the saved arm style");
      return empty;
    }
    return saved;
  }

  // Makes a SaveAndApplyCyberwareCustomizationDataRequest with the given fields set, the others left
  // as a new request has them, and queues it on the system. A field not set is what `new` gives it,
  // the same as the game's own requests that don't mention it.
  //
  // The request is made by Reflection and handed over by Reflection too. Codeware returns a new
  // object typed as ISerializable, which redscript can't cast to a request, but the call checks the
  // object's real class, and that is the request the system expects.
  private static func SendArmStyle(game: GameInstance, values: array<CName>, settings: array<Variant>) -> Bool {
    let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem");
    let systemType = Reflection.GetClass(n"CyberwareCustomizationSystem");
    let requestType = Reflection.GetClass(n"SaveAndApplyCyberwareCustomizationDataRequest");
    if !IsDefined(system) || !IsDefined(systemType) || !IsDefined(requestType) {
      return false;
    }
    let queue = systemType.GetFunction(n"QueueRequest");
    let request = requestType.MakeHandle();
    if !IsDefined(queue) || !IsDefined(request) {
      HSLog("Couldn't find the game's arm style request, so the arm style stays as it is");
      return false;
    }
    let target = ToVariant(request);
    let i = 0;
    while i < ArraySize(values) {
      let field = requestType.GetProperty(values[i]);
      if !IsDefined(field) {
        HSLog(s"The arm style request has no \(NameToString(values[i])), so the arm style stays as it is");
        return false;
      }
      field.SetValue(target, settings[i]);
      i += 1;
    }
    let args: array<Variant>;
    ArrayPush(args, target);
    let sent = false;
    queue.Call(system, args, sent);
    if !sent {
      HSLog("Couldn't hand the arm style request to the game, so the arm style stays as it is");
    }
    return sent;
  }

  // Calls a no-argument function of a TweakDB record on its real class, for record types 2.31 lacks.
  private static func CallRecord(record: ref<TweakDBRecord>, name: CName) -> Variant {
    let empty: Variant;
    let type = Reflection.GetClassOf(ToVariant(record), true);
    if !IsDefined(type) {
      return empty;
    }
    let function = type.GetFunction(name);
    if !IsDefined(function) {
      return empty;
    }
    let noArgs: array<Variant>;
    let ok = false;
    let result = function.Call(record, noArgs, ok);
    return ok ? result : empty;
  }

  // The game's own EquipmentSystemPlayerData.HasLongSleeves: a LongSleeve or BodySuit tag on what V
  // wears over the torso, chest or as an outfit.
  private static func HasLongSleeves(ctx: ref<HotswapContext>) -> Bool {
    let owner = Reflection.GetClass(n"EquipmentSystemPlayerData");
    if !IsDefined(owner) {
      return false;
    }
    let check = owner.GetStaticFunction(n"HasLongSleeves");
    if !IsDefined(check) {
      return false;
    }
    let puppet: wref<ScriptedPuppet> = ctx.player;
    let args: array<Variant>;
    ArrayPush(args, ToVariant(puppet));
    let ok = false;
    let result = check.Call(args, ok);
    return ok && FromVariant<Bool>(result);
  }

  public static func SameArmStyle(a: ref<HotswapArmStyle>, b: ref<HotswapArmStyle>) -> Bool {
    if !IsDefined(a) || !IsDefined(b) {
      return !IsDefined(a) && !IsDefined(b);
    }
    if ItemID.GetTDBID(a.item) != ItemID.GetTDBID(b.item) {
      return false;
    }
    return !ItemID.IsValid(a.item)
      || (Equals(a.enabled, b.enabled) && a.primary == b.primary && a.secondary == b.secondary);
  }
}

// One arm look from the Glamdoc. An invalid item means plain arms, with no style.
public class HotswapArmStyle {
  public let item: ItemID;
  public let enabled: Bool;
  public let primary: Int32;
  public let secondary: Int32;
}
