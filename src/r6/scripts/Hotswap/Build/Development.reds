// Hotswap - changing perks and attributes.
//
// These calls are synchronous, as they are in the game's own reset (OnResetConfirmed), so the result
// of each is known at once and this whole file runs inside one tick.
//
// The perk tree has an order both ways: a perk can't be sold while anything above it has levels, and
// can't be bought until everything below it is maxed. Rather than sort the tree, selling and buying
// repeat until nothing is left to do. Whatever is blocked this pass is free the next, and a pass that
// moves nothing means the rest will never move.

enum HotswapDevelopmentResult {
  Done = 0,
  Blocked = 1,    // the game won't sell a perk while cyberware depends on it
  Stuck = 2,
}

public abstract class HotswapDevelopment {

  public static func Run(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>, out problems: array<String>) -> HotswapDevelopmentResult {
    let sold = HotswapDevelopment.Sell(ctx, plan);
    if NotEquals(sold, HotswapDevelopmentResult.Done) {
      return sold;
    }
    if !HotswapDevelopment.SetAttributes(ctx, plan) {
      return HotswapDevelopmentResult.Stuck;
    }
    HotswapDevelopment.Relock(ctx);
    HotswapDevelopment.Buy(ctx, plan, problems);
    return HotswapDevelopmentResult.Done;
  }

  // CanSellNewPerk is asked before every sale, not once at the start. It compares the capacity free
  // now with what one perk gives, so two capacity perks can each pass on their own and still leave V
  // over the limit between them. The game only stays safe because a player sells them one at a time.
  private static func Sell(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>) -> HotswapDevelopmentResult {
    let passes = 0;
    while passes < 64 {
      let left = false;
      let moved = false;
      for want in plan.perks {
        while ctx.dev.IsNewPerkBought(want.perk) > want.level {
          let allowed = PlayerDevelopmentSystem.CanSellNewPerk(ctx.player, want.perk);
          if !allowed.success {
            return HotswapDevelopmentResult.Blocked;
          }
          let sold: Int32;
          if !ctx.dev.SellNewPerk(want.perk, sold) {
            left = true;
            break;
          }
          moved = true;
          HotswapDevelopment.AnnounceSold(ctx, want.perk, sold);
        }
      }
      if !left {
        return HotswapDevelopmentResult.Done;
      }
      if !moved {
        return HotswapDevelopmentResult.Stuck;
      }
      passes += 1;
    }
    return HotswapDevelopmentResult.Stuck;
  }

  // The refund in ResetAttribute is paid whether or not the attribute really dropped, so each one is
  // read back. Lowering all of them first means the points are there for the raises.
  private static func SetAttributes(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>) -> Bool {
    for want in plan.attributes {
      if want.value < Cast<Int32>(ctx.dev.GetAttributeValue(want.stat)) {
        ctx.dev.ResetAttribute(want.stat);
        if Cast<Int32>(ctx.dev.GetAttributeValue(want.stat)) != 3 {
          HSLog(s"Attribute \(HotswapNames.OfStat(want.stat)) did not reset");
          return false;
        }
        HotswapDevelopment.AnnounceAttribute(ctx, want.stat);
      }
    }
    for want in plan.attributes {
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

  // The game's reset locks everything, so it never meets a perk that is unlocked but now above V's
  // attributes. Changing only what differs can leave those behind, and the perk screen would then
  // offer perks V can't have. Only level 0 perks: locking one with levels loses it without removing
  // its effect (LockNewPerk).
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
      for want in plan.perks {
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
    for want in plan.perks {
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

  // The perk screen tells these same three parties, and the inventory keeps its own cache of what
  // perks do to items.
  private static func AnnounceSold(ctx: ref<HotswapContext>, perk: gamedataNewPerkType, level: Int32) -> Void {
    let evt = new NewPerkSoldEvent();
    evt.perkType = perk;
    evt.perkLevelSold = level;
    GameInstance.GetUISystem(ctx.game).QueueEvent(evt);
    ctx.player.QueueEvent(evt);
    let request = new SellNewPerk();
    request.Set(ctx.player, perk);
    UIInventoryScriptableSystem.GetInstance(ctx.game).QueueRequest(request);
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
