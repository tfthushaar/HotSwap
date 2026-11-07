// Hotswap - changing perks and attributes.
//
// A build change takes the order a respec takes at a ripperdoc. By the time this runs, every piece of
// cyberware is already off (HotswapApply), so nothing can hold a perk in place. Then everything is
// reset with the game's own calls, the ones its Reset button makes (OnResetConfirmed): ResetNewPerks
// sells and locks every perk, and ResetAttributes puts every attribute back to 3 and refunds it.
// Attributes are bought next, because perks need them, and perks last.
//
// These calls are synchronous, so the result of each is known at once and this whole file runs inside
// one tick. Buying repeats until nothing is left to do, since a perk can't be bought until everything
// below it is maxed. Whatever is blocked one pass is free the next, and a pass that buys nothing
// means the rest will never come.

enum HotswapDevelopmentResult {
  Done = 0,
  Stuck = 1,
}

public abstract class HotswapDevelopment {

  public static func Run(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, out problems: array<String>) -> HotswapDevelopmentResult {
    if !plan.ChangesDevelopment() {
      return HotswapDevelopmentResult.Done;
    }
    if !HotswapDevelopment.ResetAll(ctx) || !HotswapDevelopment.SetAttributes(ctx, plan) {
      return HotswapDevelopmentResult.Stuck;
    }
    HotswapDevelopment.Buy(ctx, plan, problems);
    HotswapDevelopment.Relock(ctx);
    return HotswapDevelopmentResult.Done;
  }

  // ResetNewPerks tells the perk screen and V what it sold. The inventory keeps its own cache of what
  // perks do to items, and is told here, as the perk screen tells it after a sale.
  private static func ResetAll(ctx: ref<HotswapContext>) -> Bool {
    let sold: array<gamedataNewPerkType>;
    let i = 0;
    let count = HotswapNames.PerkCount();
    while i < count {
      let perk = HotswapNames.PerkAt(i);
      if ctx.dev.IsNewPerkBought(perk) > 0 {
        ArrayPush(sold, perk);
      }
      i += 1;
    }
    ctx.dev.ResetNewPerks();
    for perk in sold {
      if ctx.dev.IsNewPerkBought(perk) > 0 {
        HSLog(s"Perk \(HotswapNames.OfPerk(perk)) did not reset");
        return false;
      }
      let request = new SellNewPerk();
      request.Set(ctx.player, perk);
      UIInventoryScriptableSystem.GetInstance(ctx.game).QueueRequest(request);
    }
    ctx.dev.ResetAttributes();
    for stat in HotswapNames.Attributes() {
      if Cast<Int32>(ctx.dev.GetAttributeValue(stat)) != 3 {
        HSLog(s"Attribute \(HotswapNames.OfStat(stat)) did not reset");
        return false;
      }
      HotswapDevelopment.AnnounceAttribute(ctx, stat);
    }
    return true;
  }

  private static func SetAttributes(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>) -> Bool {
    for want in plan.attributeTargets {
      let guard = 0;
      while Cast<Int32>(ctx.dev.GetAttributeValue(want.stat)) < want.value && guard < 64 {
        if !ctx.dev.BuyAttribute(want.stat) {
          HSLog(s"Could not raise \(HotswapNames.OfStat(want.stat)) to \(want.value)");
          return false;
        }
        guard += 1;
      }
      HotswapDevelopment.AnnounceAttribute(ctx, want.stat);
    }
    return true;
  }

  // The reset locks every perk. Buying unlocks what the attributes now reach, and this locks anything
  // left unlocked above them, as the game's own screens expect. Only level 0 perks: locking one with
  // levels loses it without removing its effect (LockNewPerk).
  private static func Relock(ctx: ref<HotswapContext>) -> Void {
    for tree in HotswapNames.PerkTrees() {
      let perks: array<wref<NewPerk_Record>>;
      RPGManager.GetAttributeDataRecord(tree).Perks(perks);
      for record in perks {
        let perk = record.Type();
        if ctx.dev.IsNewPerkUnlocked(perk)
          && ctx.dev.IsNewPerkBought(perk) == 0
          && !ctx.dev.HasEnoughtAttributePoints(perk) {
          ctx.dev.LockNewPerk(perk);
          let locked = new NewPerkLockedEvent();
          locked.perkType = perk;
          GameInstance.GetUISystem(ctx.game).QueueEvent(locked);
        }
      }
      ctx.dev.UnlockFreeNewPerks(tree);
    }
  }

  private static func Unlock(ctx: ref<HotswapContext>) -> Void {
    for tree in HotswapNames.PerkTrees() {
      ctx.dev.UnlockFreeNewPerks(tree);
    }
  }

  // A perk that can't be bought is reported and the swap carries on. Losing one perk isn't worth
  // undoing the whole build for, and a perk mod can make one unreachable.
  private static func Buy(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, out problems: array<String>) -> Void {
    let passes = 0;
    let left = true;
    while left && passes < 64 {
      left = false;
      let moved = false;
      HotswapDevelopment.Unlock(ctx);
      for want in plan.perkTargets {
        while ctx.dev.IsNewPerkBought(want.perk) < want.level {
          if !ctx.dev.IsNewPerkUnlocked(want.perk) || !ctx.dev.BuyNewPerk(want.perk) {
            left = true;
            break;
          }
          moved = true;
          HotswapDevelopment.AnnounceBought(ctx, want.perk);
        }
      }
      if !moved {
        break;
      }
      passes += 1;
    }
    for want in plan.perkTargets {
      if ctx.dev.IsNewPerkBought(want.perk) < want.level {
        ArrayPush(problems, HotswapText.PerkName(want.perk));
      }
    }
  }

  // The game's buy request does this after every attribute. The blackboard is what makes the
  // inventory flush its cached cyberware stats, so without it the numbers on screen go stale.
  private static func AnnounceAttribute(ctx: ref<HotswapContext>, stat: gamedataStatType) -> Void {
    let evt = new AttributeBoughtEvent();
    evt.attributeType = stat;
    GameInstance.GetUISystem(ctx.game).QueueEvent(evt);
    let definition = GetAllBlackboardDefs().UI_AttributeBought;
    let blackboard = GameInstance.GetBlackboardSystem(ctx.game).Get(definition);
    if IsDefined(blackboard) {
      let data: AttributeBoughtData;
      data.attribute = stat;
      data.value = Cast<Int32>(ctx.dev.GetAttributeValue(stat));
      blackboard.SetVariant(definition.attribute, ToVariant(data));
      blackboard.SignalVariant(definition.attribute);
    }
  }

  private static func AnnounceBought(ctx: ref<HotswapContext>, perk: gamedataNewPerkType) -> Void {
    let evt = new NewPerkBoughtEvent();
    evt.perkType = perk;
    GameInstance.GetUISystem(ctx.game).QueueEvent(evt);
    let request = new BuyNewPerk();
    request.Set(ctx.player, perk);
    UIInventoryScriptableSystem.GetInstance(ctx.game).QueueRequest(request);
  }
}
