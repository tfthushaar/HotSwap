// Hotswap - the five build slots on the inventory's first page.
//
// They stand in a column beside OUTFIT, in the page's own panel. They were first beside the outfit
// row on the Outfit screen, but that row takes the whole width of a 16:9 screen, and five more slots
// ran off the edge. The first page also has them one click from opening the inventory.
//
// The slots are the game's own widget with the game's own controller, which gives the row the same
// states and animation for free. Their events are routed here before the outfit code can see them,
// so a click on a build can't reach the wardrobe.

enum HotswapRowMode {
  Builds = 0,
  Recommend = 1,
}

enum HotswapPopup {
  None = 0,
  SaveName = 1,
  RenameName = 2,
  ConfirmOverwrite = 3,
  ConfirmClear = 4,
  ConfirmPartial = 5,
  ConfirmReplace = 6,
  Message = 7,
}

public class HotswapRow {
  private let m_player: wref<PlayerPuppet>;
  private let m_tooltips: wref<gameuiTooltipsManager>;
  private let m_hints: wref<ButtonHints>;
  private let m_controller: wref<gameuiInventoryGameController>;
  private let m_root: wref<inkCompoundWidget>;
  private let m_label: wref<inkText>;
  private let m_slots: array<wref<WardrobeOutfitSlotController>>;
  private let m_active: Bool;
  private let m_mode: HotswapRowMode;
  private let m_target: Int32;
  private let m_hovered: Int32;
  private let m_hoverTarget: wref<inkWidget>;
  private let m_drafts: array<ref<HotswapDraft>>;
  private let m_token: ref<inkGameNotificationToken>;
  private let m_popup: HotswapPopup;
  private let m_popupSlot: Int32;
  private let m_popupPlan: ref<HotswapPlan>;
  private let m_popupDraft: ref<HotswapDraft>;

  public func Attach(player: wref<PlayerPuppet>, tooltips: wref<gameuiTooltipsManager>, hints: wref<ButtonHints>, controller: wref<gameuiInventoryGameController>, root: wref<inkCompoundWidget>, label: wref<inkText>) -> Void {
    this.m_player = player;
    this.m_tooltips = tooltips;
    this.m_hints = hints;
    this.m_controller = controller;
    this.m_root = root;
    this.m_label = label;
    this.m_hovered = -1;
    let sys = this.System();
    if IsDefined(sys) {
      sys.SetListener(this);
    }
  }

  public func AddSlot(slot: wref<WardrobeOutfitSlotController>) -> Void {
    if IsDefined(slot) {
      slot.HotswapAdopt(this, ArraySize(this.m_slots));
      ArrayPush(this.m_slots, slot);
    }
  }

  private func System() -> ref<HotswapSystem> {
    return IsDefined(this.m_player) ? HotswapSystem.Get(this.m_player.GetGame()) : null;
  }

  private func Context() -> ref<HotswapContext> {
    return HotswapContext.Make(this.m_player);
  }

  public func SetActive(active: Bool) -> Void {
    this.m_active = active;
    this.m_root.SetVisible(active);
    if active {
      this.Refresh();
    } else {
      this.m_mode = HotswapRowMode.Builds;
      // The hints and tooltip share their names with the inventory's own, so this is only safe to
      // clear when they are ours.
      if this.m_hovered >= 0 {
        this.ClearHover();
      }
    }
  }

  // ---- Showing state ---------------------------------------------------------------------------

  public func Refresh() -> Void {
    if !this.m_active {
      return;
    }
    if Equals(this.m_mode, HotswapRowMode.Recommend) {
      this.ShowRecommendations();
    } else {
      this.ShowBuilds();
    }
  }

  private func ShowBuilds() -> Void {
    let sys = this.System();
    let ctx = this.Context();
    if !IsDefined(sys) || !IsDefined(ctx) {
      return;
    }
    let busy = sys.IsBusy();
    let worn = "";
    let i = 0;
    for slot in this.m_slots {
      slot.HotswapText(IntToString(i + 1));
      let used = sys.IsUsed(i);
      let lit = false;
      if used && !busy {
        lit = HotswapPlanner.Make(ctx, sys, i).IsWorn();
      }
      slot.Update(used && !busy, lit);
      if lit && StrLen(worn) == 0 {
        worn = sys.GetName(i);
      }
      i += 1;
    }
    this.m_label.SetText(StrLen(worn) > 0 ? HotswapText.RowLabelNamed(worn) : HotswapText.RowLabel());
  }

  private func ShowRecommendations() -> Void {
    let i = 0;
    for slot in this.m_slots {
      let filled = i < ArraySize(this.m_drafts);
      slot.HotswapText(filled ? this.m_drafts[i].letter : "");
      slot.Update(filled, false);
      i += 1;
    }
    this.m_label.SetText(HotswapText.RecommendLabel(this.m_target));
  }

  // ---- Hover -----------------------------------------------------------------------------------

  public func OnSlotHover(index: Int32, target: wref<inkWidget>) -> Void {
    this.m_hovered = index;
    this.m_hoverTarget = target;
    this.ShowTooltip(index, target);
    this.ShowHints(index);
  }

  // The cursor can stay on a slot while what the slot means changes under it, and the game sends no
  // new hover event for that.
  private func RefreshHover() -> Void {
    if this.m_hovered >= 0 && IsDefined(this.m_hoverTarget) {
      this.m_tooltips.HideTooltips();
      this.ShowTooltip(this.m_hovered, this.m_hoverTarget);
      this.ShowHints(this.m_hovered);
    }
  }

  public func OnSlotHoverOut() -> Void {
    this.ClearHover();
  }

  private func ClearHover() -> Void {
    this.m_hovered = -1;
    if IsDefined(this.m_tooltips) {
      this.m_tooltips.HideTooltips();
    }
    this.ClearHints();
  }

  private func ShowTooltip(index: Int32, target: wref<inkWidget>) -> Void {
    let data = new MessageTooltipData();
    if Equals(this.m_mode, HotswapRowMode.Recommend) {
      if index >= ArraySize(this.m_drafts) {
        return;
      }
      data.Title = this.m_drafts[index].name;
      data.Description = this.m_drafts[index].Tooltip();
    } else {
      let sys = this.System();
      let ctx = this.Context();
      if !IsDefined(sys) || !IsDefined(ctx) {
        return;
      }
      if sys.IsUsed(index) {
        data.Title = sys.GetName(index);
        data.Description = HotswapText.Tooltip(HotswapPlanner.Make(ctx, sys, index));
      } else {
        data.Title = HotswapText.EmptyTitle();
        data.Description = HotswapText.EmptyBody();
      }
    }
    // The column is near the screen's right and bottom edges, so the tooltip opens left and centred.
    this.m_tooltips.ShowTooltipAtWidget(0, target, data, gameuiETooltipPlacement.LeftCenter, true);
  }

  private func ClearHints() -> Void {
    if IsDefined(this.m_hints) {
      this.m_hints.RemoveButtonHint(n"click");
      this.m_hints.RemoveButtonHint(n"unequip_item");
      this.m_hints.RemoveButtonHint(n"preview_item");
      this.m_hints.RemoveButtonHint(n"drop_item");
      this.m_hints.RemoveButtonHint(n"disassemble_item");
    }
  }

  // Y is both unequip_item and disassemble_item on a gamepad, so each slot state gives it one
  // meaning. The Z hint is for keyboards only, or a gamepad would show Y twice.
  private func ShowHints(index: Int32) -> Void {
    this.ClearHints();
    if Equals(this.m_mode, HotswapRowMode.Recommend) {
      this.m_hints.AddButtonHint(n"click", HotswapText.HintCreate());
      this.m_hints.AddButtonHint(n"unequip_item", HotswapText.HintBack());
      return;
    }
    let sys = this.System();
    if !IsDefined(sys) {
      return;
    }
    if sys.IsUsed(index) {
      this.m_hints.AddButtonHint(n"click", HotswapText.HintSwitch());
      this.m_hints.AddButtonHint(n"unequip_item", HotswapText.HintSaveOver());
      this.m_hints.AddButtonHint(n"preview_item", HotswapText.HintRename());
      this.m_hints.AddButtonHint(n"drop_item", HotswapText.HintClear());
      if this.m_player.PlayerLastUsedKBM() {
        this.m_hints.AddButtonHint(n"disassemble_item", HotswapText.HintRecommend());
      }
    } else {
      this.m_hints.AddButtonHint(n"click", HotswapText.HintSave());
      this.m_hints.AddButtonHint(n"unequip_item", HotswapText.HintRecommend());
    }
  }

  // ---- Input -----------------------------------------------------------------------------------

  public func OnSlotAction(index: Int32, evt: ref<inkPointerEvent>) -> Void {
    let sys = this.System();
    if !IsDefined(sys) || sys.IsBusy() || IsDefined(this.m_token) {
      return;
    }
    // Hotswap is about V. Saving during a Johnny segment would save Johnny's gear.
    if this.m_player.IsReplacer() || this.m_player.IsJohnnyReplacer() {
      this.Tell(HotswapText.RowLabel(), HotswapText.NotAsJohnny());
      return;
    }
    let primary = evt.IsAction(n"click") || evt.IsAction(n"tap");
    let saveKey = evt.IsAction(n"unequip_item");
    let recommendKey = evt.IsAction(n"disassemble_item");

    if Equals(this.m_mode, HotswapRowMode.Recommend) {
      if primary {
        this.Create(index);
      } else {
        if saveKey || recommendKey {
          this.LeaveRecommend();
        }
      }
      return;
    }

    let used = sys.IsUsed(index);
    if primary {
      if used {
        this.Switch(index);
      } else {
        this.AskName(index, HotswapPopup.SaveName, HotswapText.SaveTitle());
      }
    } else {
      if saveKey {
        if used {
          this.Confirm(HotswapPopup.ConfirmOverwrite, index, HotswapText.OverwriteTitle(), HotswapText.Overwrite(sys.GetName(index)));
        } else {
          this.EnterRecommend(index);
        }
      } else {
        if recommendKey {
          this.EnterRecommend(index);
        } else {
          if evt.IsAction(n"preview_item") && used {
            this.AskName(index, HotswapPopup.RenameName, HotswapText.RenameTitle());
          } else {
            if evt.IsAction(n"drop_item") && used {
              this.Confirm(HotswapPopup.ConfirmClear, index, HotswapText.ClearTitle(), HotswapText.ClearBody(sys.GetName(index)));
            }
          }
        }
      }
    }
  }

  // ---- Switching -------------------------------------------------------------------------------

  private func Switch(index: Int32) -> Void {
    let sys = this.System();
    let ctx = this.Context();
    if !IsDefined(sys) || !IsDefined(ctx) {
      return;
    }
    let plan = HotswapPlanner.Make(ctx, sys, index);
    if plan.IsWorn() {
      return;
    }
    let refusal = HotswapGuards.Refusal(ctx, sys, plan);
    if StrLen(refusal) > 0 {
      this.Tell(sys.GetName(index), refusal);
      return;
    }
    if ArraySize(plan.missing) > 0 {
      this.m_popupPlan = plan;
      this.Confirm(HotswapPopup.ConfirmPartial, index, HotswapText.ConfirmTitle(), HotswapText.PartialBody(plan.missing));
      return;
    }
    this.Begin(ctx, sys, plan);
  }

  private func Begin(ctx: ref<HotswapContext>, sys: ref<HotswapSystem>, plan: ref<HotswapPlan>) -> Void {
    this.ClearHover();
    sys.Start(ctx, plan);
    this.Refresh();
  }

  public func OnSwapFinished(report: ref<HotswapReport>) -> Void {
    this.Refresh();
    if IsDefined(this.m_controller) {
      this.m_controller.HotswapRefreshItems();
    }
    if report.rolledBack {
      this.Tell(HotswapText.FailedTitle(), HotswapText.ReportLine(report) + "\n" + report.reason);
    } else {
      if ArraySize(report.problems) > 0 {
        this.Tell(report.name, HotswapText.ReportLine(report));
      }
    }
  }

  // ---- Recommended builds ----------------------------------------------------------------------

  private func EnterRecommend(index: Int32) -> Void {
    let ctx = this.Context();
    if !IsDefined(ctx) {
      return;
    }
    this.m_drafts = HotswapRecommender.All(ctx);
    this.m_target = index;
    this.m_mode = HotswapRowMode.Recommend;
    this.Refresh();
    this.RefreshHover();
  }

  private func LeaveRecommend() -> Void {
    this.m_mode = HotswapRowMode.Builds;
    ArrayClear(this.m_drafts);
    this.Refresh();
    this.RefreshHover();
  }

  private func Create(index: Int32) -> Void {
    let sys = this.System();
    if !IsDefined(sys) || index >= ArraySize(this.m_drafts) {
      return;
    }
    let draft = this.m_drafts[index];
    if sys.IsUsed(this.m_target) {
      this.m_popupDraft = draft;
      this.Confirm(HotswapPopup.ConfirmReplace, this.m_target, HotswapText.ReplaceTitle(), HotswapText.ReplaceBody(sys.GetName(this.m_target), draft.name));
      return;
    }
    sys.SaveDraft(this.m_target, draft);
    this.LeaveRecommend();
  }

  // ---- Popups ----------------------------------------------------------------------------------

  private func Open(token: ref<inkGameNotificationToken>, popup: HotswapPopup, slot: Int32) -> Void {
    this.m_popup = popup;
    this.m_popupSlot = slot;
    this.m_token = token;
    this.m_token.RegisterListener(this, n"OnPopupClosed");
  }

  private func Confirm(popup: HotswapPopup, slot: Int32, title: String, body: String) -> Void {
    this.Open(GenericMessageNotification.Show(this.m_controller, title, body, GenericMessageNotificationType.YesNo), popup, slot);
  }

  private func Tell(title: String, body: String) -> Void {
    if IsDefined(this.m_token) {
      return;
    }
    this.Open(GenericMessageNotification.Show(this.m_controller, title, body, GenericMessageNotificationType.Confirm), HotswapPopup.Message, -1);
  }

  private func AskName(slot: Int32, popup: HotswapPopup, title: String) -> Void {
    this.Open(GenericMessageNotification.ShowInput(this.m_controller, title, HotswapText.SaveBody(), GenericMessageNotificationType.ConfirmCancel), popup, slot);
  }

  private func CleanName(text: String, slot: Int32) -> String {
    let name = StrLen(text) > 20 ? StrLeft(text, 20) : text;
    return StrLen(name) > 0 ? name : HotswapText.DefaultName(slot);
  }

  protected cb func OnPopupClosed(data: ref<inkGameNotificationData>) -> Bool {
    this.m_token = null;
    let closed = data as GenericMessageNotificationCloseData;
    let popup = this.m_popup;
    let slot = this.m_popupSlot;
    this.m_popup = HotswapPopup.None;
    if !IsDefined(closed) {
      return false;
    }
    let yes = Equals(closed.result, GenericMessageNotificationResult.Yes);
    let confirm = Equals(closed.result, GenericMessageNotificationResult.Confirm);
    let sys = this.System();
    if !IsDefined(sys) {
      return false;
    }
    switch popup {
      case HotswapPopup.SaveName:
        if confirm {
          sys.Save(this.m_player, slot, this.CleanName(closed.input, slot));
        }
        break;
      case HotswapPopup.RenameName:
        if confirm {
          sys.Rename(slot, this.CleanName(closed.input, slot));
        }
        break;
      case HotswapPopup.ConfirmOverwrite:
        if yes {
          sys.Save(this.m_player, slot, sys.GetName(slot));
        }
        break;
      case HotswapPopup.ConfirmClear:
        if yes {
          sys.Clear(slot);
        }
        break;
      case HotswapPopup.ConfirmPartial:
        if yes {
          this.BeginConfirmed();
        }
        this.m_popupPlan = null;
        break;
      case HotswapPopup.ConfirmReplace:
        if yes && IsDefined(this.m_popupDraft) {
          sys.SaveDraft(slot, this.m_popupDraft);
          this.LeaveRecommend();
        }
        this.m_popupDraft = null;
        break;
      default:
        break;
    }
    this.Refresh();
    this.RefreshHover();
    return true;
  }

  // The world can't have changed behind a popup in a menu, but the player's answer is worth nothing
  // if a guard would now refuse, so they run again.
  private func BeginConfirmed() -> Void {
    let sys = this.System();
    let ctx = this.Context();
    if !IsDefined(sys) || !IsDefined(ctx) || !IsDefined(this.m_popupPlan) {
      return;
    }
    let plan = this.m_popupPlan;
    if StrLen(HotswapGuards.Refusal(ctx, sys, plan)) == 0 {
      this.Begin(ctx, sys, plan);
    }
  }
}

// ---- The slot widget ---------------------------------------------------------------------------

@addField(WardrobeOutfitSlotController)
public let m_hotswapRow: wref<HotswapRow>;

@addMethod(WardrobeOutfitSlotController)
public func HotswapAdopt(row: wref<HotswapRow>, index: Int32) -> Void {
  this.m_hotswapRow = row;
  this.Setup(index, false, false, false);
}

@addMethod(WardrobeOutfitSlotController)
public func HotswapText(text: String) -> Void {
  inkTextRef.SetText(this.m_slotNumberText, text);
}

@wrapMethod(WardrobeOutfitSlotController)
protected cb func OnHoverOver(e: ref<inkPointerEvent>) -> Bool {
  if !IsDefined(this.m_hotswapRow) {
    return wrappedMethod(e);
  }
  this.m_hovered = true;
  this.UpdateState();
  this.m_hotswapRow.OnSlotHover(this.m_index, e.GetTarget());
  return true;
}

@wrapMethod(WardrobeOutfitSlotController)
protected cb func OnHoverOut(e: ref<inkPointerEvent>) -> Bool {
  if !IsDefined(this.m_hotswapRow) {
    return wrappedMethod(e);
  }
  this.m_hovered = false;
  this.UpdateState();
  this.m_hotswapRow.OnSlotHoverOut();
  return true;
}

// The game's version ignores a click on a disabled slot, and an empty slot has to open the save
// prompt. So this takes every action, for empty slots too.
@wrapMethod(WardrobeOutfitSlotController)
protected cb func OnRelease(e: ref<inkPointerEvent>) -> Bool {
  if !IsDefined(this.m_hotswapRow) {
    return wrappedMethod(e);
  }
  this.PlaySound(n"Button", n"OnPress");
  this.m_hotswapRow.OnSlotAction(this.m_index, e);
  return true;
}

// ---- The inventory screen ----------------------------------------------------------------------

@addField(gameuiInventoryGameController)
private let m_hotswapRow: ref<HotswapRow>;

@addMethod(gameuiInventoryGameController)
private func HotswapBuildRow() -> Void {
  let page = inkWidgetRef.Get(this.m_defaultWrapper) as inkCompoundWidget;
  if !IsDefined(page) {
    HSLog("The inventory's first page wasn't found, so there is no row.");
    return;
  }

  // In the page's own 3840 by 2160 layout: level with the OUTFIT slot, and just clear of the RELATED
  // buttons, which reach 3191. Five slots of 194 and their gaps end about where those buttons do.
  let root = new inkCanvas();
  root.SetName(n"hotswapRow");
  root.SetSize(new Vector2(216.0, 1002.0));
  root.SetMargin(new inkMargin(3220.0, 630.0, 0.0, 0.0));
  root.Reparent(page);

  let panel = new inkVerticalPanel();
  panel.SetName(n"hotswapSlots");
  panel.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 8.0));
  panel.Reparent(root);

  // The label hangs from its bottom edge, as the game's own do, so it sits above the slots.
  let label = new inkText();
  label.SetName(n"hotswapLabel");
  label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  label.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  label.BindProperty(n"tintColor", n"MainColors.Red");
  label.BindProperty(n"fontWeight", n"MainColors.BodyFontWeight");
  label.BindProperty(n"fontSize", n"MainColors.ReadableSmall");
  label.SetLetterCase(textLetterCase.UpperCase);
  label.SetFitToContent(true);
  label.SetAnchorPoint(new Vector2(0.0, 1.0));
  label.SetMargin(new inkMargin(0.0, -32.0, 0.0, 0.0));
  label.Reparent(root);

  let row = new HotswapRow();
  row.Attach(this.m_player, this.m_TooltipsManager, this.m_buttonHintsController, this, root, label);
  let i = 0;
  while i < HotswapSlotCount() {
    let widget = this.SpawnFromLocal(panel, n"wardrobeOutfitSlot");
    if IsDefined(widget) {
      row.AddSlot(widget.GetController() as WardrobeOutfitSlotController);
    }
    i += 1;
  }
  this.m_hotswapRow = row;
  row.SetActive(Equals(this.m_mode, InventoryModes.Default));
}

@addMethod(gameuiInventoryGameController)
public func HotswapRefreshItems() -> Void {
  this.m_InventoryManager.MarkToRebuild();
  this.RefreshUI();
}

// The whole page is ready by the end of this, and it runs once each time the inventory opens.
@wrapMethod(gameuiInventoryGameController)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
  let result = wrappedMethod(userData);
  if !IsDefined(this.m_hotswapRow) {
    this.HotswapBuildRow();
  }
  return result;
}

// Every move between the first page and an item screen goes through this. The page's own transition
// isn't enough to hide the slots: it only animates, and they must not take clicks behind a screen.
@wrapMethod(gameuiInventoryGameController)
private final func SwapMode(mode: InventoryModes) -> Void {
  wrappedMethod(mode);
  if IsDefined(this.m_hotswapRow) {
    this.m_hotswapRow.SetActive(Equals(mode, InventoryModes.Default));
  }
}

// V's gear can change on this page, and the lit slot has to follow it.
@wrapMethod(gameuiInventoryGameController)
private final func RefreshUI() -> Void {
  wrappedMethod();
  if IsDefined(this.m_hotswapRow) {
    this.m_hotswapRow.Refresh();
  }
}
