// Hotswap - unlimited attribute resets.
//
// Making a build by hand means respeccing over and over, and the game allows one reset per
// playthrough. That limit is a single quest fact, read in three places in this controller and
// nowhere else in the scripts. Clearing it at all three frees saves that already used their reset,
// keeps the button available after each use, and covers a quest setting it while the screen is open.
//
// Everything else stays the game's: the confirmation, the refund, the refusal in combat, and
// CanSellNewPerks, which protects cyberware that depends on the perks being sold.

@addMethod(NewPerksCategoriesGameController)
private func HotswapFreeReset() -> Void {
  if IsDefined(this.m_questSystem) {
    this.m_questSystem.SetFact(n"ResetAttributeDisabled", 0);
  }
}

@wrapMethod(NewPerksCategoriesGameController)
private final func ResolveResetAttributesButtonVisibility() -> Void {
  this.HotswapFreeReset();
  wrappedMethod();
}

@wrapMethod(NewPerksCategoriesGameController)
protected cb func OnResetAttributesButtonClick(evt: ref<inkPointerEvent>) -> Bool {
  this.HotswapFreeReset();
  return wrappedMethod(evt);
}

@wrapMethod(NewPerksCategoriesGameController)
protected cb func OnResetConfirmed(data: ref<inkGameNotificationData>) -> Bool {
  let result = wrappedMethod(data);
  this.HotswapFreeReset();
  this.ResolveResetAttributesButtonVisibility();
  return result;
}
