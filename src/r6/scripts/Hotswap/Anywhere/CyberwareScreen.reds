// Hotswap - changing cyberware without a ripperdoc.
//
// The Cyberware screen in the hub already is the ripperdoc: the same controller, with the same doll,
// capacity bar and item lists, in a mode with no vendor. Two tests at the top of OnSlotClick make it
// read-only. One looks at m_screen. The other looks at m_isActivePanel, which only a vendor's tabs
// ever set. So for an equip or a remove, the controller is told it is at a ripperdoc for exactly the
// length of the game's own handler. That handler is what enforces the rules that live only in this
// screen: eyes, capacity boosters, arm styles and equip requirements.
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
  let wasActive = this.m_isActivePanel;
  let area = this.m_hoverArea;
  let wanted = IsDefined(evt.uiInventoryItem) && !evt.uiInventoryItem.IsEquipped();
  this.m_screen = CyberwareScreenType.Ripperdoc;
  this.m_isActivePanel = true;
  // Normally set once the meters' intro ends. Nothing shows that happens on this screen, and they
  // only keep a click from landing mid-animation, so they mustn't be what stops an equip here.
  this.m_isCapacityBarReady = true;
  this.m_isArmorBarReady = true;
  let result = wrappedMethod(evt);
  this.m_screen = CyberwareScreenType.Inventory;
  // Back to false, or the game's handler would take an unequip in combat, which this wrap leaves to it.
  this.m_isActivePanel = wasActive;
  // The handler clears the hover area when it acts, and several of its paths stop without a word.
  if wanted && NotEquals(area, gamedataEquipmentArea.Invalid) && Equals(this.m_hoverArea, area) {
    HSLog("A click on the Cyberware screen changed nothing. Ready for an equip: " + ToString(this.m_hasEquipEventTriggered));
  }
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
