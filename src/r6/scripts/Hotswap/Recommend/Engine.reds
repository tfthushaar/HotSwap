// Hotswap - making a build from what V owns.
//
// A draft holds the same rows a saved build does, so once it is saved nothing else in the mod knows
// where it came from. Every choice is made from live data. Attributes come first because perks need
// them, perks come second because they decide which slots exist, and cyberware last because it has
// to meet the requirements of both.

public class HotswapDraft {
  public let archetype: Int32;
  public let name: String;
  public let letter: String;
  public let blurb: String;
  public let fit: Int32;
  public let rows: array<ref<HotswapEntry>>;
  public let uses: array<String>;
  public let notes: array<String>;
  public let attributes: String;
  public let perkPoints: Int32;
  public let capacityUsed: Float;
  public let capacityTotal: Float;

  public func Add(kind: Int32, key: CName, value: Int32, item: ItemID) -> Void {
    let entry = new HotswapEntry();
    entry.kind = kind;
    entry.key = key;
    entry.value = value;
    entry.item = item;
    ArrayPush(this.rows, entry);
  }

  public func AddPart(host: ItemID, attach: TweakDBID, part: ItemID) -> Void {
    let entry = new HotswapEntry();
    entry.kind = HotswapKindPart();
    entry.host = host;
    entry.attach = attach;
    entry.item = part;
    ArrayPush(this.rows, entry);
  }

  public func Tooltip() -> String {
    let text = this.blurb + "\nFit for V: " + IntToString(this.fit) + "%";
    if ArraySize(this.uses) > 0 {
      text += "\nUses: " + HotswapText.Join(this.uses);
    }
    text += "\nAttributes: " + this.attributes;
    text += "\nPerks: " + IntToString(this.perkPoints) + " points";
    text += "\nCapacity: " + IntToString(RoundF(this.capacityUsed)) + " / " + IntToString(RoundF(this.capacityTotal));
    if ArraySize(this.notes) > 0 {
      text += "\n" + HotswapText.Join(this.notes);
    }
    return text;
  }
}

// What the engine can choose from. Scanning V's whole inventory for every slot of every build would
// be tens of thousands of lookups on a click, so it is sorted once and shared by all five.
public class HotswapStock {
  public let cyberware: array<wref<gameItemData>>;
  public let weapons: array<wref<gameItemData>>;
  public let programs: array<ItemID>;
  public let perkNames: array<String>;
  public let perkTiers: array<Int32>;

  public static func Of(ctx: ref<HotswapContext>) -> ref<HotswapStock> {
    let self = new HotswapStock();
    let index = 0;
    let perks = HotswapNames.PerkCount();
    while index < perks {
      let perk = HotswapNames.PerkAt(index);
      ArrayPush(self.perkNames, NameToString(HotswapNames.OfPerk(perk)));
      ArrayPush(self.perkTiers, HotswapRecommender.TierOf(perk));
      index += 1;
    }
    let bag = HotswapBag.Of(ctx);
    for data in bag.items {
      if IsDefined(data) {
        let id = data.GetID();
        let area = EquipmentSystem.GetEquipAreaType(id);
        if HotswapNames.IsCyberwareArea(area) {
          ArrayPush(self.cyberware, data);
        } else {
          if Equals(area, gamedataEquipmentArea.Weapon) {
            ArrayPush(self.weapons, data);
          } else {
            if Equals(RPGManager.GetItemType(id), gamedataItemType.Prt_Program) {
              ArrayPush(self.programs, id);
            }
          }
        }
      }
    }
    // Quickhacks on the current deck count as owned, though they aren't in the inventory.
    let deck = ctx.equip.GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
    if ItemID.IsValid(deck) {
      let slots = ItemModificationSystem.GetAllSlots(ctx.player, deck);
      for slot in slots {
        if Equals(slot.status, ESlotState.Taken) && HotswapRecommender.IsProgramSlot(slot.slotID) {
          ArrayPush(self.programs, slot.installedPart);
        }
      }
    }
    return self;
  }
}

public class HotswapRecommender {
  private let m_ctx: ref<HotswapContext>;
  private let m_type: ref<HotswapArchetype>;
  private let m_draft: ref<HotswapDraft>;
  private let m_stock: ref<HotswapStock>;
  private let m_bag: ref<HotswapBag>;
  private let m_attributes: array<Int32>;     // index matches HotswapNames.Attributes()
  private let m_levels: array<Int32>;         // perk level by enum index
  private let m_primaryLeft: Int32;
  private let m_relicLeft: Int32;
  private let m_budget: Float;
  private let m_used: Float;
  private let m_attunedPicks: Int32;
  private let m_picks: Int32;
  private let m_fitSystem: Int32;
  private let m_fitArms: Int32;
  private let m_fitWeapons: Int32;

  // All five, best fit for V first.
  public static func All(ctx: ref<HotswapContext>) -> array<ref<HotswapDraft>> {
    let drafts: array<ref<HotswapDraft>>;
    let stock = HotswapStock.Of(ctx);
    let id = 0;
    while id < HotswapArchetype.Count() {
      let engine = new HotswapRecommender();
      let draft = engine.Run(ctx, HotswapArchetype.Get(id), stock);
      let at = 0;
      while at < ArraySize(drafts) && drafts[at].fit >= draft.fit {
        at += 1;
      }
      ArrayInsert(drafts, at, draft);
      id += 1;
    }
    return drafts;
  }

  public func Run(ctx: ref<HotswapContext>, type: ref<HotswapArchetype>, stock: ref<HotswapStock>) -> ref<HotswapDraft> {
    this.m_ctx = ctx;
    this.m_type = type;
    this.m_stock = stock;
    this.m_bag = new HotswapBag();
    let draft = new HotswapDraft();
    draft.archetype = type.id;
    draft.name = type.name;
    draft.letter = type.letter;
    draft.blurb = type.blurb;
    this.m_draft = draft;

    this.SpendAttributes();
    this.SpendPerks();
    this.ChooseCyberware();
    this.ChooseWeapons();

    let attuned = this.m_picks > 0 ? (this.m_attunedPicks * 15) / this.m_picks : 0;
    draft.fit = this.m_fitSystem + this.m_fitArms + this.m_fitWeapons + attuned;
    draft.capacityUsed = this.m_used;
    draft.capacityTotal = this.m_budget;
    return draft;
  }

  // ---- Attributes ------------------------------------------------------------------------------

  private func AttributeIndex(stat: gamedataStatType) -> Int32 {
    return ArrayFindFirst(HotswapNames.Attributes(), stat);
  }

  private func Attribute(stat: gamedataStatType) -> Int32 {
    let index = this.AttributeIndex(stat);
    return index >= 0 ? this.m_attributes[index] : 0;
  }

  // The main attribute reaches 20 well before the others, because a build's best perks are at 20.
  // Spreading points evenly stalls everything at 15 or so, with no master perks at all and perk
  // points left over. A low-level V still gets the second attribute to 9 early, for its first perks.
  private func SpendAttributes() -> Void {
    let stats = HotswapNames.Attributes();
    ArrayResize(this.m_attributes, ArraySize(stats));
    let i = 0;
    while i < ArraySize(stats) {
      this.m_attributes[i] = 3;
      i += 1;
    }
    let points = HotswapTotals.Read(this.m_ctx).attribute;
    let order = [0, 1, 0, 0, 1, 2, 1, 2, 2];
    let tiers = [9, 9, 15, 20, 15, 9, 20, 15, 20];
    i = 0;
    while i < ArraySize(order) {
      points = this.Raise(this.m_type.attributes[order[i]], tiers[i], points);
      i += 1;
    }
    // Whatever is left goes wherever there is still room.
    for stat in stats {
      points = this.Raise(stat, 20, points);
    }
    i = 0;
    let summary = "";
    while i < ArraySize(stats) {
      this.m_draft.Add(HotswapKindAttribute(), HotswapNames.OfStat(stats[i]), this.m_attributes[i], ItemID.None());
      if this.m_attributes[i] > 3 {
        let piece = HotswapRecommender.ShortName(stats[i]) + " " + IntToString(this.m_attributes[i]);
        summary = StrLen(summary) == 0 ? piece : summary + ", " + piece;
      }
      i += 1;
    }
    this.m_draft.attributes = summary;
  }

  private func Raise(stat: gamedataStatType, to: Int32, points: Int32) -> Int32 {
    let index = this.AttributeIndex(stat);
    let step = Min(to - this.m_attributes[index], points);
    if step <= 0 {
      return points;
    }
    this.m_attributes[index] += step;
    return points - step;
  }

  private static func ShortName(stat: gamedataStatType) -> String {
    switch stat {
      case gamedataStatType.Strength:
        return "Body";
      case gamedataStatType.Reflexes:
        return "Reflexes";
      case gamedataStatType.TechnicalAbility:
        return "Tech";
      case gamedataStatType.Intelligence:
        return "Int";
      default:
        return "Cool";
    }
  }

  // ---- Perks -----------------------------------------------------------------------------------

  private func SpendPerks() -> Void {
    let count = HotswapNames.PerkCount();
    ArrayResize(this.m_levels, count);
    let totals = HotswapTotals.Read(this.m_ctx);
    this.m_primaryLeft = totals.primary;
    this.m_relicLeft = totals.relic;

    // Each branch is finished before the next starts, because the archetype lists them best first.
    // Going tier by tier across all of them instead spends the points on cheap perks in side trees,
    // and the main tree's master perks are never reached.
    for branch in this.m_type.branches {
      for tier in [0, 4, 9, 15, 20] {
        let i = 0;
        while i < count {
          if this.m_stock.perkTiers[i] == tier && StrBeginsWith(this.m_stock.perkNames[i], branch) {
            this.Take(HotswapNames.PerkAt(i), 0);
          }
          i += 1;
        }
      }
    }

    // Points still left go to the rest of the trees this build's attributes reach, rather than
    // sitting unspent.
    for stat in this.m_type.attributes {
      let tree = HotswapRecommender.TreePrefix(stat);
      for tier in [4, 9, 15, 20] {
        let i = 0;
        while i < count {
          if this.m_stock.perkTiers[i] == tier && StrBeginsWith(this.m_stock.perkNames[i], tree) {
            this.Take(HotswapNames.PerkAt(i), 0);
          }
          i += 1;
        }
      }
    }

    let i = 0;
    while i < count {
      if this.m_levels[i] > 0 {
        let perk = HotswapNames.PerkAt(i);
        this.m_draft.Add(HotswapKindPerk(), HotswapNames.OfPerk(perk), this.m_levels[i], ItemID.None());
        if !this.m_ctx.dev.IsNewPerkEspionage(perk) {
          this.m_draft.perkPoints += this.m_levels[i];
        }
      }
      i += 1;
    }
  }

  private static func TreePrefix(stat: gamedataStatType) -> String {
    switch stat {
      case gamedataStatType.Strength:
        return "Body_";
      case gamedataStatType.Reflexes:
        return "Reflexes_";
      case gamedataStatType.TechnicalAbility:
        return "Tech_";
      case gamedataStatType.Intelligence:
        return "Intelligence_";
      default:
        return "Cool_";
    }
  }

  public static func TierOf(perk: gamedataNewPerkType) -> Int32 {
    let record = RPGManager.GetNewPerkRecord(perk);
    if !IsDefined(record) || !IsDefined(record.Tier()) {
      return -1;
    }
    return record.Tier().RequiredAttributePoints();
  }

  private func PerkAffordableAttribute(record: ref<NewPerk_Record>) -> Bool {
    let required = record.Tier().RequiredAttributePoints();
    if required <= 0 {
      return true;
    }
    let stat = PlayerDevelopmentData.AttributeDataTypeToStatType(record.Attribute().Type());
    return this.Attribute(stat) >= required;
  }

  // Maxes a perk, buying what it needs first. Returns whether it ended up maxed, since that is what
  // anything above it requires. Partial levels are kept: points in a perk are not wasted.
  private func Take(perk: gamedataNewPerkType, depth: Int32) -> Bool {
    if depth > 16 {
      return false;
    }
    let record = RPGManager.GetNewPerkRecord(perk);
    if !IsDefined(record) {
      return false;
    }
    let index = EnumInt(perk);
    let most = record.GetLevelsCount();
    if most <= 0 || !IsDefined(record.Tier()) || !IsDefined(record.Attribute()) {
      return false;
    }
    if this.m_levels[index] >= most {
      return true;
    }
    if !this.PerkAffordableAttribute(record) {
      return false;
    }
    let parents: array<wref<NewPerk_Record>>;
    record.RequiresPerks(parents);
    for parent in parents {
      if !this.Take(parent.Type(), depth + 1) {
        return false;
      }
    }
    let relic = this.m_ctx.dev.IsNewPerkEspionage(perk);
    let cost = relic ? HotswapTotals.RelicCost(this.m_ctx, perk) : 1;
    while this.m_levels[index] < most {
      if relic {
        if this.m_relicLeft < cost {
          return false;
        }
        this.m_relicLeft -= cost;
      } else {
        if this.m_primaryLeft < cost {
          return false;
        }
        this.m_primaryLeft -= cost;
      }
      this.m_levels[index] += 1;
    }
    return true;
  }

  private func LevelOf(perk: gamedataNewPerkType) -> Int32 {
    return this.m_levels[EnumInt(perk)];
  }

  // ---- Items -----------------------------------------------------------------------------------

  private static func Rank(data: wref<gameItemData>) -> Float {
    let rank = HotswapRecommender.QualityRank(RPGManager.GetItemDataQuality(data));
    return RPGManager.IsItemIconic(data) ? rank + 1.0 : rank;
  }

  // The enum runs alphabetically, so its order says nothing about which is better.
  private static func QualityRank(quality: gamedataQuality) -> Float {
    let rank: Float;
    switch quality {
      case gamedataQuality.Common:
        rank = 1.0;
        break;
      case gamedataQuality.CommonPlus:
        rank = 1.5;
        break;
      case gamedataQuality.Uncommon:
        rank = 2.0;
        break;
      case gamedataQuality.UncommonPlus:
        rank = 2.5;
        break;
      case gamedataQuality.Rare:
        rank = 3.0;
        break;
      case gamedataQuality.RarePlus:
        rank = 3.5;
        break;
      case gamedataQuality.Epic:
        rank = 4.0;
        break;
      case gamedataQuality.EpicPlus:
        rank = 4.5;
        break;
      case gamedataQuality.Legendary:
        rank = 5.0;
        break;
      case gamedataQuality.LegendaryPlus:
        rank = 5.5;
        break;
      case gamedataQuality.LegendaryPlusPlus:
        rank = 6.0;
        break;
      default:
        rank = 0.0;
        break;
    }
    return rank;
  }

  private func Type(item: ItemID) -> CName {
    return TweakDBInterface.GetCName(ItemID.GetTDBID(item) + t".cyberwareType", n"");
  }

  // What the cyberware UI shows as attunement: a logic package carrying the attunement helper stat,
  // with the attribute's icon on it.
  private func Attunement(item: ItemID) -> gamedataStatType {
    let record = RPGManager.GetItemRecord(item);
    if !IsDefined(record) {
      return gamedataStatType.Invalid;
    }
    let packages: array<wref<GameplayLogicPackage_Record>>;
    record.OnEquip(packages);
    record.OnAttach(packages);
    let helper = TweakDBInterface.GetStatRecord(t"BaseStats.AttunementHelper");
    for package in packages {
      let ui = package.UIData();
      if IsDefined(ui) && ui.StatsContains(helper) {
        let icon = NameToString(ui.IconPath());
        if StrContains(icon, "Body") {
          return gamedataStatType.Strength;
        }
        if StrContains(icon, "Reflexes") {
          return gamedataStatType.Reflexes;
        }
        if StrContains(icon, "TechnicalAbility") {
          return gamedataStatType.TechnicalAbility;
        }
        if StrContains(icon, "Intelligence") {
          return gamedataStatType.Intelligence;
        }
        if StrContains(icon, "Cool") {
          return gamedataStatType.Cool;
        }
      }
    }
    return gamedataStatType.Invalid;
  }

  // The same check as equipping, except against this draft's attributes, not V's current ones.
  private func MeetsRequirements(data: wref<gameItemData>) -> Bool {
    let requirements = RPGManager.GetEquipRequirements(this.m_ctx.player, data);
    for need in requirements {
      if this.AttributeIndex(need.statType) >= 0 {
        if Cast<Float>(this.Attribute(need.statType)) < need.requiredValue {
          return false;
        }
      } else {
        if NotEquals(need.statType, gamedataStatType.HumanityAvailable)
          && this.m_ctx.Stat(need.statType) < need.requiredValue {
          return false;
        }
      }
    }
    return !RPGManager.IsItemBroken(data);
  }

  private func Score(item: ItemID, data: wref<gameItemData>) -> Float {
    let score = HotswapRecommender.Rank(data) * 10.0;
    let rank = this.m_type.AttributeRank(this.Attunement(item));
    if rank >= 0 {
      score += Cast<Float>(15 - rank * 5);
    }
    return score;
  }

  private func CanUse(item: ItemID, data: wref<gameItemData>, area: gamedataEquipmentArea) -> Bool {
    if NotEquals(EquipmentSystem.GetEquipAreaType(item), area) || this.m_bag.IsClaimed(item) {
      return false;
    }
    // A generated copy comes with its perk. The original is the item to choose.
    if !HotswapGear.Same(HotswapGear.Canon(this.m_ctx, area, item), item) {
      return false;
    }
    if RPGManager.IsItemAdaptiveStemCells(ItemID.GetTDBID(item)) && this.LevelOf(gamedataNewPerkType.Tech_Central_Perk_3_3) == 0 {
      return false;
    }
    if this.m_used + HotswapGear.Capacity(this.m_ctx, item) > this.m_budget {
      return false;
    }
    return this.MeetsRequirements(data);
  }

  // The best piece for a slot. wanted limits it to a list of cyberware types, if given.
  private func Best(area: gamedataEquipmentArea, const wanted: script_ref<array<CName>>, typed: Bool) -> ItemID {
    let best = ItemID.None();
    let bestScore = -1.0;
    for data in this.m_stock.cyberware {
      let id = data.GetID();
      if this.CanUse(id, data, area) && (!typed || ArrayContains(Deref(wanted), this.Type(id))) {
        let score = this.Score(id, data);
        if score > bestScore {
          bestScore = score;
          best = id;
        }
      }
    }
    return best;
  }

  private func Place(area: gamedataEquipmentArea, slot: Int32, item: ItemID) -> Void {
    this.m_bag.Claim(item);
    this.m_used += HotswapGear.Capacity(this.m_ctx, item);
    this.m_draft.Add(HotswapKindGear(), HotswapNames.OfArea(area), slot, item);
    this.m_picks += 1;
    let rank = this.m_type.AttributeRank(this.Attunement(item));
    if rank >= 0 {
      this.m_attunedPicks += 1;
    }
    let live = HotswapGear.Raw(this.m_ctx, area, slot);
    if HotswapGear.Same(HotswapGear.Canon(this.m_ctx, area, live), item) && !EquipmentSystem.IsItemCyberdeck(item) {
      this.KeepParts(live, item);
    }
  }

  // Attachments on a piece V already wears stay with it. Without rows for them, they would be lost
  // if the swap had to take that piece off to sell a perk.
  private func KeepParts(live: ItemID, named: ItemID) -> Void {
    let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, live);
    for slot in slots {
      if Equals(slot.status, ESlotState.Taken) && HotswapGear.IsTrackedPart(slot.slotID, slot.innerItemData) {
        this.m_draft.AddPart(named, slot.slotID, slot.installedPart);
      }
    }
  }

  private func PlaceEmpty(area: gamedataEquipmentArea, slot: Int32) -> Void {
    this.m_draft.Add(HotswapKindGear(), HotswapNames.OfArea(area), slot, ItemID.None());
  }

  private func Bonus(stat: gamedataStatType) -> Float {
    return this.m_ctx.Stat(stat);
  }

  // Capacity that comes from a perk may not be there after the swap, so the budget leaves it out. A
  // build is better off under budget than refused when it applies.
  private func ChooseCyberware() -> Void {
    this.m_budget = this.Bonus(gamedataStatType.Humanity) - this.Bonus(gamedataStatType.Tech_Central_Perk_2_2_Humanity);

    // Eyes never change here, so what they cost has to be counted.
    let eyes = 0;
    let eyeSlots = this.m_ctx.equip.GetNumberOfSlots(gamedataEquipmentArea.EyesCW, true);
    while eyes < eyeSlots {
      let item = HotswapGear.Raw(this.m_ctx, gamedataEquipmentArea.EyesCW, eyes);
      if ItemID.IsValid(item) {
        this.m_bag.Claim(item);
        this.m_used += HotswapGear.Capacity(this.m_ctx, item);
      }
      eyes += 1;
    }

    this.ChooseSystem();
    this.ChooseArms();

    for area in [gamedataEquipmentArea.FrontalCortexCW, gamedataEquipmentArea.NervousSystemCW, gamedataEquipmentArea.CardiovascularSystemCW, gamedataEquipmentArea.IntegumentarySystemCW, gamedataEquipmentArea.ImmuneSystemCW, gamedataEquipmentArea.LegsCW, gamedataEquipmentArea.HandsCW, gamedataEquipmentArea.MusculoskeletalSystemCW] {
      this.FillArea(area);
    }
  }

  // Two slots depend on perks, and this draft's perks may differ from V's. The third skeleton slot
  // comes with Tech_Central_Milestone_3 at level 3, and the second hands slot with Tech_Central_Perk_3_2.
  private func SlotsAfterPerks(area: gamedataEquipmentArea) -> Int32 {
    let count = this.m_ctx.equip.GetNumberOfSlots(area, false);
    if Equals(area, gamedataEquipmentArea.MusculoskeletalSystemCW) && this.LevelOf(gamedataNewPerkType.Tech_Central_Milestone_3) < 3 {
      return Min(count, 2);
    }
    if Equals(area, gamedataEquipmentArea.HandsCW) && this.LevelOf(gamedataNewPerkType.Tech_Central_Perk_3_2) == 0 {
      return Min(count, 1);
    }
    return count;
  }

  // A slot left empty here is emptied by the swap. What V wore there is either over budget or beyond
  // the draft's attributes, so it couldn't stay anyway.
  private func FillArea(area: gamedataEquipmentArea) -> Void {
    if this.m_ctx.equip.GetEquipAreaIndex(area) < 0 {
      return;
    }
    let none: array<CName>;
    let open = this.SlotsAfterPerks(area);
    let total = this.m_ctx.equip.GetNumberOfSlots(area, true);
    let slot = 0;
    while slot < total {
      let item = slot < open ? this.Best(area, none, false) : ItemID.None();
      if ItemID.IsValid(item) {
        this.Place(area, slot, item);
      } else {
        this.PlaceEmpty(area, slot);
      }
      slot += 1;
    }
  }

  private func ChooseSystem() -> Void {
    let area = gamedataEquipmentArea.SystemReplacementCW;
    let item = this.Best(area, this.m_type.systems, true);
    if ItemID.IsValid(item) {
      this.m_fitSystem = 35;
    } else {
      ArrayPush(this.m_draft.notes, s"V doesn't own the right operating system for this build.");
      let none: array<CName>;
      item = this.Best(area, none, false);
    }
    if ItemID.IsValid(item) {
      this.Place(area, 0, item);
      ArrayPush(this.m_draft.uses, HotswapGear.DisplayName(this.m_ctx, item));
      if EquipmentSystem.IsItemCyberdeck(item) {
        this.LoadDeck(item);
      }
    }
  }

  private func ChooseArms() -> Void {
    let area = gamedataEquipmentArea.ArmsCW;
    let item = this.Best(area, this.m_type.arms, true);
    if ItemID.IsValid(item) {
      this.m_fitArms = 15;
      this.Place(area, 0, item);
      ArrayPush(this.m_draft.uses, HotswapGear.DisplayName(this.m_ctx, item));
      return;
    }
    let current = HotswapGear.Raw(this.m_ctx, area, 0);
    if ItemID.IsValid(current) {
      this.m_used += HotswapGear.Capacity(this.m_ctx, current);
    }
  }

  // Fills the deck with V's best quickhacks. Only one of each kind fits, because the game removes
  // others of the same shard type on install (RemoveOtherShards).
  private func LoadDeck(deck: ItemID) -> Void {
    let attach: array<TweakDBID>;
    let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, deck);
    for slot in slots {
      if HotswapRecommender.IsProgramSlot(slot.slotID) {
        ArrayPush(attach, slot.slotID);
      }
    }
    let programs: array<ItemID>;
    let scores: array<Float>;
    for id in this.m_stock.programs {
      let record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(id));
      let score = HotswapRecommender.QualityRank(RPGManager.GetItemQualityFromRecord(record));
      this.OfferProgram(id, score, programs, scores);
    }
    let used = 0;
    while used < ArraySize(attach) && ArraySize(programs) > 0 {
      let best = 0;
      let i = 1;
      while i < ArraySize(scores) {
        if scores[i] > scores[best] {
          best = i;
        }
        i += 1;
      }
      this.m_draft.AddPart(deck, attach[used], programs[best]);
      ArrayErase(programs, best);
      ArrayErase(scores, best);
      used += 1;
    }
  }

  private func OfferProgram(item: ItemID, score: Float, out programs: array<ItemID>, out scores: array<Float>) -> Void {
    let shard = TweakDBInterface.GetCName(ItemID.GetTDBID(item) + t".shardType", n"");
    let i = 0;
    while i < ArraySize(programs) {
      if Equals(TweakDBInterface.GetCName(ItemID.GetTDBID(programs[i]) + t".shardType", n""), shard) {
        if score > scores[i] {
          programs[i] = item;
          scores[i] = score;
        }
        return;
      }
      i += 1;
    }
    ArrayPush(programs, item);
    ArrayPush(scores, score);
  }

  public static func IsProgramSlot(slot: TweakDBID) -> Bool {
    return slot == t"AttachmentSlots.CyberdeckProgram1"
      || slot == t"AttachmentSlots.CyberdeckProgram2"
      || slot == t"AttachmentSlots.CyberdeckProgram3"
      || slot == t"AttachmentSlots.CyberdeckProgram4"
      || slot == t"AttachmentSlots.CyberdeckProgram5"
      || slot == t"AttachmentSlots.CyberdeckProgram6"
      || slot == t"AttachmentSlots.CyberdeckProgram7"
      || slot == t"AttachmentSlots.CyberdeckProgram8";
  }

  // ---- Weapons ---------------------------------------------------------------------------------

  private func WeaponScore(item: ItemID, data: wref<gameItemData>) -> Float {
    let record = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(item));
    if !IsDefined(record) {
      return 0.0;
    }
    let evolution = IsDefined(record.Evolution()) ? record.Evolution().Type() : gamedataWeaponEvolution.Invalid;
    let affinity = this.m_type.WeaponAffinity(RPGManager.GetItemType(item), evolution);
    if affinity <= 0.0 {
      return 0.0;
    }
    return affinity * (data.GetStatValueByType(gamedataStatType.EffectiveDPS) + HotswapRecommender.Rank(data) * 10.0);
  }

  // best of what's left, limited to melee or to ranged if asked. 0 is either, 1 melee, 2 ranged.
  private func BestWeapon(kind: Int32) -> ItemID {
    let best = ItemID.None();
    let bestScore = 0.0;
    for data in this.m_stock.weapons {
      let id = data.GetID();
      if !this.m_bag.IsClaimed(id) && (kind == 0 || Equals(kind == 1, WeaponObject.IsMelee(id))) && this.m_ctx.equip.IsEquippable(data) {
        let score = this.WeaponScore(id, data);
        if score > bestScore {
          bestScore = score;
          best = id;
        }
      }
    }
    return best;
  }

  // Up to three weapons, mixing ranged and melee when V owns both. A slot with nothing suitable keeps
  // what is in it. Left-hand slots are cleared, since this build doesn't plan around dual wielding.
  private func ChooseWeapons() -> Void {
    let picks: array<ItemID>;
    let open = Min(3, this.m_ctx.equip.GetNumberOfSlots(gamedataEquipmentArea.Weapon, false));
    for kind in [2, 1, 0] {
      let item = ArraySize(picks) < open ? this.BestWeapon(kind) : ItemID.None();
      if ItemID.IsValid(item) {
        this.m_bag.Claim(item);
        ArrayPush(picks, item);
      }
    }
    if ArraySize(picks) == 0 {
      ArrayPush(this.m_draft.notes, "V doesn't own weapons for this build, so V keeps the current ones.");
      return;
    }
    let area = gamedataEquipmentArea.Weapon;
    let slot = 0;
    for item in picks {
      this.m_draft.Add(HotswapKindGear(), HotswapNames.OfArea(area), slot, item);
      ArrayPush(this.m_draft.uses, HotswapGear.DisplayName(this.m_ctx, item));
      slot += 1;
    }
    for left in [EnumInt(WeaponSlot.LeftSlot_1), EnumInt(WeaponSlot.LeftSlot_2), EnumInt(WeaponSlot.LeftSlot_3)] {
      if HotswapGear.SlotExists(this.m_ctx, area, left) {
        this.PlaceEmpty(area, left);
      }
    }
    this.m_fitWeapons = (ArraySize(picks) * 35) / 3;
  }
}
