// Hotswap - the per-save system. It owns the saved builds and runs swaps.
//
// A swap runs here and not in the row's controller, so closing the inventory midway can't strand it.
// See Core/Types.reds before changing any persistent field.

public class HotswapSystem extends ScriptableSystem {
  private persistent let m_schema: Int32;
  private persistent let m_headers: array<ref<HotswapHeader>>;
  private persistent let m_entries: array<ref<HotswapEntry>>;
  private persistent let m_spare: Int32;

  private let m_settings: ref<HotswapSettings>;
  private let m_apply: ref<HotswapApply>;
  private let m_listener: wref<HotswapRow>;
  private let m_lastSwapAt: Float;

  public static func Get(game: GameInstance) -> ref<HotswapSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"HotswapSystem") as HotswapSystem;
  }

  private func OnAttach() -> Void {
    this.EnsureState();
    if !IsDefined(this.m_settings) {
      this.m_settings = new HotswapSettings();
      this.m_settings.Register();
    }
  }

  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    this.EnsureState();
  }

  private func OnDetach() -> Void {
    if IsDefined(this.m_settings) {
      this.m_settings.Unregister();
    }
    this.m_apply = null;
  }

  // The hook the engine asks before any save. A swap leaves V half changed between stages, so no
  // save may land in the middle of one. A swap that has stopped ticking must not block saving for
  // the rest of the session, so the answer also depends on it having ticked recently.
  private func IsSavingLocked() -> Bool {
    return IsDefined(this.m_apply) && this.m_apply.IsRunning() && !this.m_apply.IsStalled();
  }

  // Safe to run more than once: OnAttach comes first on a new game, OnRestored after it on a load.
  private func EnsureState() -> Void {
    let kept: array<ref<HotswapEntry>>;
    for entry in this.m_entries {
      if IsDefined(entry) && entry.build >= 0 && entry.build <= HotswapUndoBuild() {
        ArrayPush(kept, entry);
      }
    }
    this.m_entries = kept;

    let index = 0;
    while index <= HotswapUndoBuild() {
      if !IsDefined(this.Header(index)) {
        let header = new HotswapHeader();
        header.index = index;
        ArrayPush(this.m_headers, header);
      }
      index += 1;
    }

    if this.m_schema != HotswapSchema() {
      HSLog(s"Save data schema \(this.m_schema) -> \(HotswapSchema())");
      this.m_schema = HotswapSchema();
    }
  }

  private func Header(index: Int32) -> ref<HotswapHeader> {
    for header in this.m_headers {
      if IsDefined(header) && header.index == index {
        return header;
      }
    }
    return null;
  }

  public func GetSettings() -> ref<HotswapSettings> {
    return this.m_settings;
  }

  public func IsUsed(index: Int32) -> Bool {
    let header = this.Header(index);
    return IsDefined(header) && header.used;
  }

  public func GetName(index: Int32) -> String {
    let header = this.Header(index);
    return IsDefined(header) ? NameToString(header.name) : "";
  }

  public func GetOrigin(index: Int32) -> Int32 {
    let header = this.Header(index);
    return IsDefined(header) ? header.origin : 0;
  }

  public func EntriesOf(build: Int32) -> array<ref<HotswapEntry>> {
    let rows: array<ref<HotswapEntry>>;
    for entry in this.m_entries {
      if IsDefined(entry) && entry.build == build {
        ArrayPush(rows, entry);
      }
    }
    return rows;
  }

  public func ClearEntries(build: Int32) -> Void {
    let kept: array<ref<HotswapEntry>>;
    for entry in this.m_entries {
      if IsDefined(entry) && entry.build != build {
        ArrayPush(kept, entry);
      }
    }
    this.m_entries = kept;
  }

  public func AddEntry(build: Int32, kind: Int32, key: CName, value: Int32, item: ItemID) -> Void {
    let entry = new HotswapEntry();
    entry.build = build;
    entry.kind = kind;
    entry.key = key;
    entry.value = value;
    entry.item = item;
    ArrayPush(this.m_entries, entry);
  }

  public func AddPart(build: Int32, host: ItemID, attach: TweakDBID, part: ItemID) -> Void {
    let entry = new HotswapEntry();
    entry.build = build;
    entry.kind = HotswapKindPart();
    entry.host = host;
    entry.attach = attach;
    entry.item = part;
    ArrayPush(this.m_entries, entry);
  }

  private func Mark(index: Int32, name: String, origin: Int32) -> Void {
    let header = this.Header(index);
    if IsDefined(header) {
      header.used = true;
      header.name = StringToName(name);
      header.origin = origin;
    }
  }

  public func Save(player: wref<PlayerPuppet>, index: Int32, name: String) -> Bool {
    let ctx = HotswapContext.Make(player);
    if !IsDefined(ctx) || this.IsBusy() {
      return false;
    }
    HotswapCapture.Into(ctx, this, index);
    this.Mark(index, name, 0);
    HSLog(s"Saved V's current build to slot \(index + 1) as \(name)");
    return true;
  }

  public func SaveDraft(index: Int32, draft: ref<HotswapDraft>) -> Bool {
    if this.IsBusy() {
      return false;
    }
    this.ClearEntries(index);
    for row in draft.rows {
      row.build = index;
      ArrayPush(this.m_entries, row);
    }
    this.Mark(index, draft.name, draft.archetype + 1);
    HSLog(s"Created recommended build \(draft.name) in slot \(index + 1)");
    return true;
  }

  public func Rename(index: Int32, name: String) -> Void {
    let header = this.Header(index);
    if IsDefined(header) && header.used {
      header.name = StringToName(name);
    }
  }

  public func Clear(index: Int32) -> Void {
    let header = this.Header(index);
    if IsDefined(header) {
      header.used = false;
      header.name = n"";
      header.origin = 0;
    }
    this.ClearEntries(index);
  }

  public func IsBusy() -> Bool {
    return IsDefined(this.m_apply) && this.m_apply.IsRunning();
  }

  public func SetListener(row: wref<HotswapRow>) -> Void {
    this.m_listener = row;
  }

  public func SecondsSinceSwap() -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance())) - this.m_lastSwapAt;
  }

  // The first swap of a session has nothing to wait for.
  public func CooldownLeft() -> Float {
    if this.m_lastSwapAt <= 0.0 || !IsDefined(this.m_settings) {
      return 0.0;
    }
    return Cast<Float>(this.m_settings.cooldownSeconds) - this.SecondsSinceSwap();
  }

  public func Start(ctx: ref<HotswapContext>, plan: ref<HotswapPlan>) -> Void {
    if this.IsBusy() {
      return;
    }
    this.m_apply = new HotswapApply();
    this.m_apply.Begin(this, ctx, plan);
  }

  public func OnSwapTick(generation: Int32) -> Void {
    if IsDefined(this.m_apply) {
      this.m_apply.Tick(generation);
    }
  }

  private func OnHotswapTick(request: ref<HotswapTick>) -> Void {
    this.OnSwapTick(request.generation);
  }

  public func OnSwapFinished(report: ref<HotswapReport>) -> Void {
    this.m_lastSwapAt = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
    if IsDefined(this.m_listener) {
      this.m_listener.OnSwapFinished(report);
    } else {
      if !report.succeeded || ArraySize(report.problems) > 0 {
        GameInstance.GetActivityLogSystem(this.GetGameInstance()).AddLog(HotswapText.ReportLine(report));
      }
    }
  }
}

public class HotswapTick extends ScriptableSystemRequest {
  public let generation: Int32;
}

public class HotswapTickCallback extends DelayCallback {
  public let game: GameInstance;
  public let generation: Int32;

  public func Call() -> Void {
    let sys = HotswapSystem.Get(this.game);
    if IsDefined(sys) {
      sys.OnSwapTick(this.generation);
    }
  }
}
