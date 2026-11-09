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

  // The equipment area that holds the Glamdoc style of V's arm cyberware. Invalid on 2.31.
  public static func ArmStyleArea() -> gamedataEquipmentArea {
    return HotswapNames.ToArea(n"ArmsCWStyle");
  }

  // Switches the arm style off the way the Glamdoc does: a SaveAndApplyCyberwareCustomizationData
  // request with enabled false, switcher index 0, and the switcher name the system has saved, since
  // the request's name is what the system saves next. Does nothing on 2.31.
  //
  // The request is made by Reflection and handed over by Reflection too. Codeware returns a new
  // object typed as ISerializable, which redscript can't cast to a request, but the call checks the
  // object's real class, and that is the request the system expects.
  public static func SwitchOffArmStyle(game: GameInstance) -> Void {
    let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem");
    let systemType = Reflection.GetClass(n"CyberwareCustomizationSystem");
    let savedType = Reflection.GetClass(n"CyberwareCustomizationPersistentData");
    let requestType = Reflection.GetClass(n"SaveAndApplyCyberwareCustomizationDataRequest");
    if !IsDefined(system) || !IsDefined(systemType) || !IsDefined(savedType) || !IsDefined(requestType) {
      return;
    }
    let getSaved = systemType.GetFunction(n"GetSavedData");
    let queue = systemType.GetFunction(n"QueueRequest");
    let savedName = savedType.GetProperty(n"switcherName");
    let enabled = requestType.GetProperty(n"enabled");
    let switcherName = requestType.GetProperty(n"switcherName");
    let switcherIndex = requestType.GetProperty(n"switcherIndex");
    if !IsDefined(getSaved) || !IsDefined(queue) || !IsDefined(savedName) || !IsDefined(enabled)
      || !IsDefined(switcherName) || !IsDefined(switcherIndex) {
      HSLog("Couldn't find the game's arm style request, so the arm style stays as it is");
      return;
    }

    let noArgs: array<Variant>;
    let read = false;
    let saved = getSaved.Call(system, noArgs, read);
    if !read {
      HSLog("Couldn't read the saved arm style, so the arm style stays as it is");
      return;
    }
    let name: CName = FromVariant<CName>(savedName.GetValue(saved));

    let request = requestType.MakeHandle();
    if !IsDefined(request) {
      return;
    }
    let target = ToVariant(request);
    let off = false;
    let first: Uint32 = 0u;
    enabled.SetValue(target, ToVariant(off));
    switcherName.SetValue(target, ToVariant(name));
    switcherIndex.SetValue(target, ToVariant(first));

    let args: array<Variant>;
    ArrayPush(args, target);
    let sent = false;
    queue.Call(system, args, sent);
    if !sent {
      HSLog("Couldn't hand the arm style request to the game, so the arm style stays as it is");
    }
  }
}
