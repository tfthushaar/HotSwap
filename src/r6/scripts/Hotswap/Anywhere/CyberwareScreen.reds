// Hotswap - changing cyberware without a ripperdoc.
//
// The Cyberware screen in the hub already is the ripperdoc: the same controller, with the same doll,
// capacity bar and item lists, in a mode with no vendor. What makes it read-only is one test at the
// top of OnSlotClick, and it only looks at m_screen. So for an equip or a remove, the controller is
// told it is at a ripperdoc for exactly the length of the game's own handler. That handler is what
// enforces the rules that live only in this screen: eyes, capacity boosters, arm styles and equip
// requirements.
//
// disassemble_item is stopped outright, because that path sells to a vendor and there isn't one.
// Buying and upgrading stay closed: there is no stock to buy from, and those need a vendor as well.

@addMethod(RipperDocGameController)
private func HotswapIsHubScreen() -> Bool {
  return Equals(this.m_screen, CyberwareScreenType.Inventory);
}

@wrapMethod(RipperDocGameController)
protected cb func OnSlotClick(evt: ref<ItemDisplayClickEvent>) -> Bool {
  if !this.HotswapIsHubScreen() {
    return wrappedMethod(evt);
  }
  if evt.actionName.IsAction(n"disassemble_item") {
    return false;
  }
  let changesGear = evt.actionName.IsAction(n"click") || evt.actionName.IsAction(n"tap") || evt.actionName.IsAction(n"unequip_item");
  if !changesGear || this.m_player.IsInCombat() {
    return wrappedMethod(evt);
  }
  this.m_screen = CyberwareScreenType.Ripperdoc;
  let result = wrappedMethod(evt);
  this.m_screen = CyberwareScreenType.Inventory;
  return result;
}

// The hub mode shows no hints, so nothing would tell the player these actions exist.
@wrapMethod(RipperDocGameController)
protected cb func OnSlotHover(evt: ref<ItemDisplayHoverOverEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if this.HotswapIsHubScreen() && Equals(this.m_filterMode, RipperdocModes.Item) {
    let item = evt.uiInventoryItem;
    if IsDefined(item) {
      if !item.IsEquipped() {
        this.m_buttonHintsController.AddButtonHint(n"select", "LocKey#246");
      } else {
        if NotEquals(item.GetEquipmentArea(), gamedataEquipmentArea.EyesCW) {
          this.m_buttonHintsController.AddButtonHint(n"unequip_item", GetLocalizedText("UI-UserActions-Unequip"));
        }
      }
    }
  }
  return result;
}
