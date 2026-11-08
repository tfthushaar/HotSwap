// Hotswap - making a build from what V owns.
//
// A draft holds the same rows a saved build does, so once it is saved nothing else in the mod knows
// where it came from. Nothing in a draft is fixed in advance. The engine starts from what V owns:
// which of V's weapons, operating system and arms suit this kind of build, and what V's cyberware is
// attuned to. That kit decides where the attribute points go and which perks are worth buying, using
// the points V has earned. Attributes come before perks because perks need them, perks before the
// final choice of gear because they decide which slots exist, and gear last because it has to meet
// the requirements of both.

public class HotswapDraft {
  public let archetype: Int32;
  public let name: String;
  public let letter: String;
  public let blurb: String;
  public let fit: Int32;
  public let blocker: String;   // why this build can't work at all. Empty for nearly every build
  public let rows: array<ref<HotswapEntry>>;
  public let uses: array<String>;
  public let chrome: array<String>;   // the cyberware the build leans on most, best first
  public let notes: array<String>;
  public let attributes: String;
  public let perkPoints: Int32;
  public let mods: Int32;
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
    if StrLen(this.blocker) > 0 {
      return this.blocker;
    }
    let text = this.blurb + "\nFit for V: " + IntToString(this.fit) + "%";
    if ArraySize(this.uses) > 0 {
      text += "\nUses: " + HotswapText.Join(this.uses);
    }
    if ArraySize(this.chrome) > 0 {
      text += "\nKey cyberware: " + HotswapText.Join(this.chrome);
    }
    text += "\nAttributes: " + this.attributes;
    text += "\nPerks: " + IntToString(this.perkPoints) + " points";
    text += "\nCapacity: " + IntToString(RoundF(this.capacityUsed)) + " / " + IntToString(RoundF(this.capacityTotal));
    if this.mods > 0 {
      text += "\nWeapon mods: " + IntToString(this.mods) + " fitted from V's own";
    }
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
  public let weapons: array<wref<gameItemData>>;   // the best copy of each weapon V owns
  public let parts: array<wref<gameItemData>>;     // weapon mods and attachments not on anything
  public let maxDps: Float;
  public let programs: array<ItemID>;
  public let perkNames: array<String>;
  public let knowledge: ref<HotswapKnowledge>;
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
            self.OfferWeapon(data);
          } else {
            if Equals(RPGManager.GetItemType(id), gamedataItemType.Prt_Program) {
              ArrayPush(self.programs, id);
            } else {
              if Equals(RPGManager.GetItemCategory(id), gamedataItemCategory.Part) {
                ArrayPush(self.parts, data);
              }
            }
          }
        }
      }
    }
    for data in self.weapons {
      self.maxDps = MaxF(self.maxDps, data.GetStatValueByType(gamedataStatType.EffectiveDPS));
    }
    self.knowledge = HotswapKnowledge.Load();
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

  // Two copies of the same weapon are one choice, and it is always the higher grade, then the one
  // that hits harder.
  private func OfferWeapon(data: wref<gameItemData>) -> Void {
    let record = ItemID.GetTDBID(data.GetID());
    let i = 0;
    while i < ArraySize(this.weapons) {
      let held = this.weapons[i];
      if ItemID.GetTDBID(held.GetID()) == record {
        let grade = HotswapRecommender.QualityRank(RPGManager.GetItemDataQuality(data));
        let heldGrade = HotswapRecommender.QualityRank(RPGManager.GetItemDataQuality(held));
        if grade > heldGrade || (grade == heldGrade
          && data.GetStatValueByType(gamedataStatType.EffectiveDPS) > held.GetStatValueByType(gamedataStatType.EffectiveDPS)) {
          this.weapons[i] = data;
        }
        return;
      }
      i += 1;
    }
    ArrayPush(this.weapons, data);
  }
}

// What a build will carry, read from V's gear. The perks it gets follow from this.
public class HotswapKit {
  public let heavy: Bool;       // shotguns and machine guns
  public let blunt: Bool;       // hammers, clubs and Gorilla Arms
  public let precise: Bool;     // pistols, revolvers, precision and sniper rifles
  public let thrown: Bool;      // knives and axes
  public let automatic: Bool;   // assault rifles and SMGs
  public let blades: Bool;      // swords and Mantis Blades
  public let smart: Bool;       // Smart weapons
  public let charged: Bool;     // Tech weapons
  public let deck: Bool;        // a cyberdeck
  public let wires: Bool;       // Monowire
  public let launcher: Bool;    // Projectile Launch System
  public let arms: Bool;        // any arms cyberware
  public let camo: Bool;        // Optical Camo
  public let silent: Bool;      // a silenced weapon, or one V can silence
}

public class HotswapRecommender {
  private let m_ctx: ref<HotswapContext>;
  private let m_type: ref<HotswapArchetype>;
  private let m_draft: ref<HotswapDraft>;
  private let m_stock: ref<HotswapStock>;
  private let m_bag: ref<HotswapBag>;
  private let m_kit: ref<HotswapKit>;
  private let m_interest: array<Float>;       // how much this build wants each HotswapStyle
  private let m_cyberScores: array<Float>;    // the worth of each of the stock's cyberware, for this build
  private let m_demand: array<Float>;         // how much V's gear leans on each attribute
  private let m_needs: array<Int32>;          // what that gear requires of each attribute
  private let m_order: array<gamedataStatType>;   // the attributes, in the order this draft favours them
  private let m_attributes: array<Int32>;     // index matches HotswapNames.Attributes()
  private let m_keepsTinkerer: Bool;          // whether cyberware keeps its Cyberware Tinkerer discount
  private let m_typeAreas: array<gamedataEquipmentArea>;
  private let m_types: array<CName>;          // cyberware types placed, one per type in an area
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

    this.Survey();
    this.Interests();
    this.OrderAttributes();
    this.SpendAttributes();
    this.SpendPerks();
    this.ChooseCyberware();
    this.ChooseWeapons();

    let attuned = this.m_picks > 0 ? (this.m_attunedPicks * 15) / this.m_picks : 0;
    draft.fit = this.m_fitSystem + this.m_fitArms + this.m_fitWeapons + attuned;
    draft.capacityUsed = this.m_used;
    draft.capacityTotal = this.m_budget;
    if StrLen(draft.blocker) > 0 {
      draft.fit = 0;
    }
    return draft;
  }

  // ---- What V owns ------------------------------------------------------------------------------

  // Reads the gear this build would be made around, before the attributes that will limit it exist.
  private func Survey() -> Void {
    let stats = HotswapNames.Attributes();
    let count = ArraySize(stats);
    ArrayResize(this.m_demand, count);
    ArrayResize(this.m_needs, count);
    this.m_kit = new HotswapKit();

    // Squared so that V's best cyberware speaks for V, and not a drawer of common parts.
    for data in this.m_stock.cyberware {
      let id = data.GetID();
      let rank = HotswapRecommender.Rank(data);
      this.AddDemand(this.Attunement(id), (rank * rank) / 36.0);
      if Equals(this.Type(id), n"OpticalCamo") {
        this.m_kit.camo = true;
      }
    }

    let none: array<CName>;
    let system = this.Strongest(gamedataEquipmentArea.SystemReplacementCW, this.m_type.systems, true);
    if !ItemID.IsValid(system) {
      system = this.Strongest(gamedataEquipmentArea.SystemReplacementCW, none, false);
    }
    this.NoteSystem(system);

    // A V with no arms this build wants keeps the ones they have, as ChooseArms does.
    let arms = this.Strongest(gamedataEquipmentArea.ArmsCW, this.m_type.arms, true);
    if !ItemID.IsValid(arms) {
      arms = HotswapGear.Raw(this.m_ctx, gamedataEquipmentArea.ArmsCW, 0);
    }
    this.NoteArms(arms);

    for kind in [2, 1, 0] {
      let item = this.BestWeapon(kind, true);
      if ItemID.IsValid(item) {
        this.m_bag.Claim(item);
        this.NoteWeapon(item);
      }
    }
    this.m_bag = new HotswapBag();
  }

  // The best piece V owns for an area, whatever it requires.
  private func Strongest(area: gamedataEquipmentArea, wanted: array<CName>, typed: Bool) -> ItemID {
    let best = ItemID.None();
    let bestRank = -1.0;
    for data in this.m_stock.cyberware {
      let id = data.GetID();
      if Equals(EquipmentSystem.GetEquipAreaType(id), area) && (!typed || ArrayContains(wanted, this.Type(id))) {
        let rank = HotswapRecommender.Rank(data);
        if rank > bestRank {
          bestRank = rank;
          best = id;
        }
      }
    }
    return best;
  }

  private func AddDemand(stat: gamedataStatType, amount: Float) -> Void {
    let index = this.AttributeIndex(stat);
    if index >= 0 {
      this.m_demand[index] += amount;
    }
  }

  private func NoteNeeds(item: ItemID) -> Void {
    let data = this.m_ctx.ItemData(item);
    if !IsDefined(data) {
      return;
    }
    let requirements = RPGManager.GetEquipRequirements(this.m_ctx.player, data);
    for need in requirements {
      let index = this.AttributeIndex(need.statType);
      if index >= 0 {
        this.m_needs[index] = Max(this.m_needs[index], CeilF(need.requiredValue));
      }
    }
  }

  private func NoteSystem(item: ItemID) -> Void {
    if !ItemID.IsValid(item) {
      return;
    }
    this.NoteNeeds(item);
    if EquipmentSystem.IsItemCyberdeck(item) {
      this.m_kit.deck = true;
      this.AddDemand(gamedataStatType.Intelligence, 4.0);
      return;
    }
    let type = this.Type(item);
    if Equals(type, n"Berserk") {
      this.AddDemand(gamedataStatType.Strength, 2.0);
    } else {
      if Equals(type, n"Sandevistan") {
        this.AddDemand(gamedataStatType.Reflexes, 2.0);
      }
    }
  }

  private func NoteArms(item: ItemID) -> Void {
    if !ItemID.IsValid(item) {
      return;
    }
    this.NoteNeeds(item);
    this.m_kit.arms = true;
    let type = this.Type(item);
    if Equals(type, n"NanoWires") {
      this.m_kit.wires = true;
      this.AddDemand(gamedataStatType.Intelligence, 3.0);
    } else {
      if Equals(type, n"MantisBlades") {
        this.m_kit.blades = true;
        this.AddDemand(gamedataStatType.Reflexes, 3.0);
      } else {
        if Equals(type, n"StrongArms") {
          this.m_kit.blunt = true;
          this.AddDemand(gamedataStatType.Strength, 3.0);
        } else {
          if Equals(type, n"ProjectileLauncher") {
            this.m_kit.launcher = true;
            this.AddDemand(gamedataStatType.TechnicalAbility, 3.0);
          }
        }
      }
    }
  }

  // Which attribute a weapon belongs to is the game's own answer: the skill its kills level up
  // (RPGManager's combat experience). A weapon's class says what else it leans on.
  private func NoteWeapon(item: ItemID) -> Void {
    this.NoteNeeds(item);
    let kit = this.m_kit;
    switch RPGManager.GetItemType(item) {
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
      case gamedataItemType.Wea_HeavyMachineGun:
      case gamedataItemType.Wea_LightMachineGun:
        kit.heavy = true;
        this.AddDemand(gamedataStatType.Strength, 3.0);
        break;
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_TwoHandedClub:
        kit.blunt = true;
        this.AddDemand(gamedataStatType.Strength, 3.0);
        break;
      case gamedataItemType.Wea_Rifle:
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_SubmachineGun:
        kit.automatic = true;
        this.AddDemand(gamedataStatType.Reflexes, 3.0);
        break;
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_LongBlade:
      case gamedataItemType.Wea_ShortBlade:
      case gamedataItemType.Wea_Chainsword:
      case gamedataItemType.Wea_Machete:
        kit.blades = true;
        this.AddDemand(gamedataStatType.Reflexes, 3.0);
        break;
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_PrecisionRifle:
        kit.precise = true;
        this.AddDemand(gamedataStatType.Cool, 3.0);
        break;
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_Axe:
        kit.thrown = true;
        this.AddDemand(gamedataStatType.Cool, 3.0);
        break;
      default:
        break;
    }
    let record = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(item));
    if IsDefined(record) && IsDefined(record.Evolution()) {
      let evolution = record.Evolution().Type();
      if Equals(evolution, gamedataWeaponEvolution.Smart) {
        kit.smart = true;
        this.AddDemand(gamedataStatType.Intelligence, 2.0);
      } else {
        if Equals(evolution, gamedataWeaponEvolution.Tech) {
          kit.charged = true;
          this.AddDemand(gamedataStatType.TechnicalAbility, 2.0);
        }
      }
    }
    if this.Quietness(item) > 0.0 {
      kit.silent = true;
    }
  }

  // The build's main attribute is what makes it this kind of build. After that, V's gear decides.
  private func OrderAttributes() -> Void {
    let rest: array<gamedataStatType>;
    for stat in HotswapNames.Attributes() {
      if NotEquals(stat, this.m_type.main) {
        ArrayPush(rest, stat);
      }
    }
    ArrayClear(this.m_order);
    ArrayPush(this.m_order, this.m_type.main);
    while ArraySize(rest) > 0 {
      let best = 0;
      let bestScore = -1.0;
      let i = 0;
      while i < ArraySize(rest) {
        let score = this.m_demand[this.AttributeIndex(rest[i])];
        let lean = ArrayFindFirst(this.m_type.lean, rest[i]);
        if lean >= 0 {
          score += 0.5 - Cast<Float>(lean) * 0.1;
        }
        if score > bestScore {
          bestScore = score;
          best = i;
        }
        i += 1;
      }
      ArrayPush(this.m_order, rest[best]);
      ArrayErase(rest, best);
    }
  }

  // Where an attribute stands in this build. Only the first three get points on purpose.
  private func OrderRank(stat: gamedataStatType) -> Int32 {
    let rank = ArrayFindFirst(this.m_order, stat);
    return rank < 3 ? rank : -1;
  }

  // ---- Attributes ------------------------------------------------------------------------------

  private func AttributeIndex(stat: gamedataStatType) -> Int32 {
    let stats = HotswapNames.Attributes();
    return ArrayFindFirst(stats, stat);
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
    // The gear this build is made around has to be usable before anything else matters, which on a
    // low-level V can take most of the points.
    for stat in this.m_order {
      points = this.Raise(stat, this.m_needs[this.AttributeIndex(stat)], points);
    }
    let order = [0, 1, 0, 0, 1, 2, 1, 2, 2];
    let tiers = [9, 9, 15, 20, 15, 9, 20, 15, 20];
    i = 0;
    while i < ArraySize(order) {
      points = this.Raise(this.m_order[order[i]], tiers[i], points);
      i += 1;
    }
    // Whatever is left goes wherever there is still room, in the order the gear asks for.
    for stat in this.m_order {
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

    // Each tree is finished before the next starts. Going tier by tier across all of them instead
    // spends the points on cheap perks in side trees, and the main tree's master perks are never
    // reached. The first pass buys only what serves what this build carries. Points still left go
    // to the rest of what its attributes reach, rather than sitting unspent.
    let trees: array<String>;
    for stat in this.m_order {
      ArrayPush(trees, HotswapRecommender.TreePrefix(stat));
    }
    ArrayPush(trees, "Espionage_");
    for tree in trees {
      this.BuyTree(tree, true);
    }
    for tree in trees {
      this.BuyTree(tree, false);
    }

    let i = 0;
    while i < count {
      if this.m_levels[i] > 0 {
        let perk = HotswapNames.PerkAt(i);
        this.m_draft.Add(HotswapKindPerk(), HotswapNames.OfPerk(perk), this.m_levels[i], ItemID.None());
        if !HotswapNames.IsRelicPerk(perk) {
          this.m_draft.perkPoints += this.m_levels[i];
        }
      }
      i += 1;
    }
  }

  private func BuyTree(tree: String, usefulOnly: Bool) -> Void {
    let count = HotswapNames.PerkCount();
    for tier in [0, 4, 9, 15, 20] {
      let i = 0;
      while i < count {
        if this.m_stock.perkTiers[i] == tier && StrBeginsWith(this.m_stock.perkNames[i], tree) {
          let perk = HotswapNames.PerkAt(i);
          if !usefulOnly || this.Serves(perk, 0) {
            this.Take(perk, 0);
          }
        }
        i += 1;
      }
    }
  }

  // Whether a branch of the tree does anything for this build's gear. Branches with no line here help
  // any build. Master and in-between perks have no line of their own: they follow their parents.
  private func BranchServes(name: String) -> Bool {
    let kit = this.m_kit;
    if StrBeginsWith(name, "Body_Left") { return kit.heavy; }
    if StrBeginsWith(name, "Body_Right") { return kit.blunt; }
    if StrBeginsWith(name, "Cool_Left") { return kit.precise; }
    if StrBeginsWith(name, "Cool_Right") { return kit.thrown || kit.silent; }
    if StrBeginsWith(name, "Reflexes_Left") { return kit.automatic; }
    if StrBeginsWith(name, "Reflexes_Right") { return kit.blades; }
    if StrBeginsWith(name, "Intelligence_Left") || StrBeginsWith(name, "Intelligence_Central") { return kit.deck; }
    if StrBeginsWith(name, "Intelligence_Right") { return kit.smart; }
    if StrBeginsWith(name, "Intelligence_Inbetween_Left_2") { return kit.wires; }
    if StrBeginsWith(name, "Tech_Right") { return kit.charged; }
    if StrBeginsWith(name, "Tech_Inbetween_Left") { return kit.launcher; }
    if StrBeginsWith(name, "Espionage_Left") { return kit.camo; }
    if StrBeginsWith(name, "Espionage_Central") { return kit.arms; }
    return true;
  }

  private func Serves(perk: gamedataNewPerkType, depth: Int32) -> Bool {
    if !this.BranchServes(this.m_stock.perkNames[EnumInt(perk)]) {
      return false;
    }
    let record = RPGManager.GetNewPerkRecord(perk);
    if !IsDefined(record) || depth > 16 {
      return true;
    }
    let parents: array<wref<NewPerk_Record>>;
    record.RequiresPerks(parents);
    for parent in parents {
      if !this.Serves(parent.Type(), depth + 1) {
        return false;
      }
    }
    return true;
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
    let relic = HotswapNames.IsRelicPerk(perk);
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

  // Grade decides. Being iconic only settles a tie between two pieces of the same grade.
  public static func Rank(data: wref<gameItemData>) -> Float {
    let rank = HotswapRecommender.QualityRank(RPGManager.GetItemDataQuality(data));
    return RPGManager.IsItemIconic(data) ? rank + 0.25 : rank;
  }

  // The enum runs alphabetically, so its order says nothing about which is better.
  public static func QualityRank(quality: gamedataQuality) -> Float {
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

  // What a piece does for this build counts most: its power and the styles it serves (HotswapKnowledge).
  // Grade comes next, so of two copies the better one wins, but a lower grade piece that suits the
  // build beats a perfect one that doesn't. Attunement to the build's attributes settles the rest.
  private func Score(item: ItemID, data: wref<gameItemData>) -> Float {
    let score = this.m_stock.knowledge.Worth(this.Type(item), this.m_interest);
    score += HotswapRecommender.Rank(data) * 3.0;
    let rank = this.OrderRank(this.Attunement(item));
    if rank >= 0 {
      score += Cast<Float>(6 - rank * 2);
    }
    // Decks differ most in their RAM.
    if EquipmentSystem.IsItemCyberdeck(item) {
      score += data.GetStatValueByType(gamedataStatType.Memory);
    }
    return score;
  }

  // ---- What this build wants ----------------------------------------------------------------------

  // Each kind of build starts with interests of its own, and V's kit adds to them: a Juggernaut with
  // a hammer leans on blunt melee, one with a shotgun on guns, a Ghost with a silenced pistol on stealth.
  private func Interests() -> Void {
    ArrayResize(this.m_interest, HotswapStyleCount());
    let i = 0;
    while i < HotswapStyleCount() {
      this.m_interest[i] = 0.0;
      i += 1;
    }
    switch this.m_type.id {
      case 0:
        this.Want(HotswapStyle.Netrun, 3.0);
        this.Want(HotswapStyle.Smart, 1.0);
        this.Want(HotswapStyle.Stealth, 1.0);
        this.Want(HotswapStyle.Sustain, 1.0);
        this.Want(HotswapStyle.Ranged, 0.5);
        this.Want(HotswapStyle.Tank, 0.5);
        this.Want(HotswapStyle.Abilities, 0.5);
        break;
      case 1:
        this.Want(HotswapStyle.Melee, 3.0);
        this.Want(HotswapStyle.Blades, 3.0);
        this.Want(HotswapStyle.Mobility, 2.0);
        this.Want(HotswapStyle.Abilities, 1.5);
        this.Want(HotswapStyle.Sustain, 1.0);
        this.Want(HotswapStyle.Tank, 1.0);
        this.Want(HotswapStyle.Precision, 0.5);
        break;
      case 2:
        this.Want(HotswapStyle.Tank, 3.0);
        this.Want(HotswapStyle.Sustain, 2.0);
        this.Want(HotswapStyle.Melee, 1.5);
        this.Want(HotswapStyle.Blunt, 1.0);
        this.Want(HotswapStyle.Ranged, 1.0);
        this.Want(HotswapStyle.Abilities, 1.0);
        break;
      case 3:
        this.Want(HotswapStyle.Stealth, 3.0);
        this.Want(HotswapStyle.Precision, 3.0);
        this.Want(HotswapStyle.Throwing, 1.0);
        this.Want(HotswapStyle.Ranged, 1.0);
        this.Want(HotswapStyle.Abilities, 1.0);
        this.Want(HotswapStyle.Sustain, 1.0);
        this.Want(HotswapStyle.Mobility, 1.0);
        break;
      default:
        this.Want(HotswapStyle.Tech, 3.0);
        this.Want(HotswapStyle.Ranged, 2.0);
        this.Want(HotswapStyle.Abilities, 1.0);
        this.Want(HotswapStyle.Sustain, 1.0);
        this.Want(HotswapStyle.Tank, 1.0);
        break;
    }
    let kit = this.m_kit;
    if kit.blades { this.Want(HotswapStyle.Blades, 2.0); this.Want(HotswapStyle.Melee, 1.0); }
    if kit.blunt { this.Want(HotswapStyle.Blunt, 2.0); this.Want(HotswapStyle.Melee, 1.0); }
    if kit.heavy { this.Want(HotswapStyle.Ranged, 1.0); this.Want(HotswapStyle.Tank, 0.5); }
    if kit.automatic { this.Want(HotswapStyle.Ranged, 1.0); }
    if kit.precise { this.Want(HotswapStyle.Precision, 1.5); this.Want(HotswapStyle.Ranged, 0.5); }
    if kit.thrown { this.Want(HotswapStyle.Throwing, 2.0); }
    if kit.smart { this.Want(HotswapStyle.Smart, 2.0); }
    if kit.charged { this.Want(HotswapStyle.Tech, 2.0); }
    if kit.deck { this.Want(HotswapStyle.Netrun, 1.0); }
    if kit.wires { this.Want(HotswapStyle.Netrun, 0.5); this.Want(HotswapStyle.Melee, 0.5); }
    if kit.launcher { this.Want(HotswapStyle.Tech, 1.0); }
    if kit.camo || kit.silent { this.Want(HotswapStyle.Stealth, 1.0); }
  }

  private func Want(style: HotswapStyle, amount: Float) -> Void {
    let i = EnumInt(style);
    this.m_interest[i] += amount;
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
    // EquipItem takes off anything of the same cyberware type in the area. Two of a kind, like an
    // iconic and its ordinary version, would knock each other off.
    if this.TypeTaken(area, this.Type(item)) {
      return false;
    }
    if this.m_used + this.DraftCost(item) > this.m_budget + HotswapRecommender.BoosterCapacity(this.m_ctx, item) {
      return false;
    }
    return this.MeetsRequirements(data);
  }

  private func TypeTaken(area: gamedataEquipmentArea, type: CName) -> Bool {
    let i = 0;
    while i < ArraySize(this.m_types) {
      if Equals(this.m_typeAreas[i], area) && Equals(this.m_types[i], type) {
        return true;
      }
      i += 1;
    }
    return false;
  }

  // ---- Capacity ----------------------------------------------------------------------------------

  // What a piece costs once this draft's perks are bought. Cyberware Tinkerer takes a point off some
  // pieces, and each of those carries the discount as a stat, so its cost without the perk is known.
  // A draft that keeps the perk at the level V has keeps the discount.
  private func DraftCost(item: ItemID) -> Float {
    let data = this.m_ctx.ItemData(item);
    if !IsDefined(data) {
      return 0.0;
    }
    let cost = data.GetStatValueByType(gamedataStatType.HumanityAllocated);
    if !this.m_keepsTinkerer {
      cost += data.GetStatValueByType(gamedataStatType.Tech_Central_Milestone_2_Discount);
    }
    return cost;
  }

  // A capacity booster raises capacity by the game's own curve of its CapacityBoosterHumanity.
  public static func BoosterCapacity(ctx: ref<HotswapContext>, item: ItemID) -> Float {
    let data = ctx.ItemData(item);
    if !IsDefined(data) || !data.HasTag(n"CapacityBooster") {
      return 0.0;
    }
    let level = data.GetStatValueByType(gamedataStatType.CapacityBoosterHumanity);
    return GameInstance.GetStatsDataSystem(ctx.game).GetValueFromCurve(n"cyberware_curves", level, n"capacity_booster_to_humanity");
  }

  // The capacity V will have once this draft's perks are bought, which is what EquipItem checks
  // against (HumanityAllocationPrereq). From V's capacity now, it takes out what V's perks and boosters
  // give, and puts back what the draft's will. Driver Update gives a fixed amount for each attribute
  // at 9 or more, and its size per attribute is read from what V gets now. Where V has nothing to read
  // it from, nothing is counted: a build under budget beats one that won't go on.
  private func DraftCapacity() -> Float {
    let ctx = this.m_ctx;
    let capacity = ctx.Stat(gamedataStatType.Humanity) - ctx.Stat(gamedataStatType.Tech_Central_Perk_2_2_Humanity);
    let systems = ctx.equip.GetNumberOfSlots(gamedataEquipmentArea.SystemReplacementCW, true);
    let slot = 0;
    while slot < systems {
      capacity -= HotswapRecommender.BoosterCapacity(ctx, HotswapGear.Raw(ctx, gamedataEquipmentArea.SystemReplacementCW, slot));
      slot += 1;
    }
    if this.LevelOf(gamedataNewPerkType.Tech_Central_Perk_2_2) > 0 {
      let now = 0;
      let then = 0;
      for stat in HotswapNames.Attributes() {
        if ctx.dev.GetAttributeValue(stat) >= 9.0 {
          now += 1;
        }
        if this.Attribute(stat) >= 9 {
          then += 1;
        }
      }
      if now > 0 {
        capacity += ctx.Stat(gamedataStatType.Tech_Central_Perk_2_2_Humanity) / Cast<Float>(now) * Cast<Float>(then);
      }
    }
    if this.LevelOf(gamedataNewPerkType.Tech_Master_Perk_3) > 0 {
      capacity += ctx.Stat(gamedataStatType.Tech_Master_Perk_3_Humanity);
    }
    return capacity;
  }

  // The best piece for a slot. wanted limits it to a list of cyberware types, if given.
  private func Best(area: gamedataEquipmentArea, wanted: array<CName>, typed: Bool) -> ItemID {
    let best = ItemID.None();
    let bestScore = -1.0;
    let i = 0;
    while i < ArraySize(this.m_stock.cyberware) {
      let data = this.m_stock.cyberware[i];
      let id = data.GetID();
      if this.CanUse(id, data, area) && (!typed || ArrayContains(wanted, this.Type(id))) {
        let score = this.m_cyberScores[i];
        if score > bestScore {
          bestScore = score;
          best = id;
        }
      }
      i += 1;
    }
    return best;
  }

  private func Place(area: gamedataEquipmentArea, slot: Int32, item: ItemID) -> Void {
    this.m_bag.Claim(item);
    this.m_used += this.DraftCost(item);
    this.m_budget += HotswapRecommender.BoosterCapacity(this.m_ctx, item);
    ArrayPush(this.m_typeAreas, area);
    ArrayPush(this.m_types, this.Type(item));
    this.m_draft.Add(HotswapKindGear(), HotswapNames.OfArea(area), slot, item);
    this.m_picks += 1;
    if this.OrderRank(this.Attunement(item)) >= 0 {
      this.m_attunedPicks += 1;
    }
    if HotswapGear.Holds(this.m_ctx, area, slot, item) && !EquipmentSystem.IsItemCyberdeck(item) {
      this.KeepParts(HotswapGear.Raw(this.m_ctx, area, slot), item);
    }
  }

  // Attachments on a piece V already wears stay with it. Without rows for them, they would be lost
  // if the swap had to take that piece off to sell a perk.
  private func KeepParts(live: ItemID, named: ItemID) -> Void {
    let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, live);
    for slot in slots {
      if Equals(slot.status, ESlotState.Taken) && HotswapGear.IsTrackedPart(live, slot.slotID, slot.innerItemData) {
        this.m_draft.AddPart(named, slot.slotID, slot.installedPart);
      }
    }
  }

  private func PlaceEmpty(area: gamedataEquipmentArea, slot: Int32) -> Void {
    this.m_draft.Add(HotswapKindGear(), HotswapNames.OfArea(area), slot, ItemID.None());
  }

  // Perks are settled by now, so capacity and costs are worked out for the draft's own perks.
  private func ChooseCyberware() -> Void {
    let tinkerer = gamedataNewPerkType.Tech_Central_Milestone_2;
    this.m_keepsTinkerer = this.LevelOf(tinkerer) >= this.m_ctx.dev.IsNewPerkBought(tinkerer);
    this.m_budget = this.DraftCapacity();

    // A piece's worth doesn't change while the build is made, so it is worked out once.
    ArrayClear(this.m_cyberScores);
    for data in this.m_stock.cyberware {
      ArrayPush(this.m_cyberScores, this.Score(data.GetID(), data));
    }

    // Eyes never change here, so what they cost has to be counted.
    let eyes = 0;
    let eyeSlots = this.m_ctx.equip.GetNumberOfSlots(gamedataEquipmentArea.EyesCW, true);
    while eyes < eyeSlots {
      let item = HotswapGear.Raw(this.m_ctx, gamedataEquipmentArea.EyesCW, eyes);
      if ItemID.IsValid(item) {
        this.m_bag.Claim(item);
        this.m_used += this.DraftCost(item);
      }
      eyes += 1;
    }

    this.ChooseSystem();
    this.ChooseArms();
    this.FillBody();
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

  // The best piece anywhere on the body goes in first, then the next best, until the slots or the
  // capacity run out. Filling one area at a time spent capacity on whichever area came first, so a
  // Second Heart could be left out for lesser pieces. A slot left empty here is emptied by the swap.
  private func FillBody() -> Void {
    let areas = [gamedataEquipmentArea.FrontalCortexCW, gamedataEquipmentArea.NervousSystemCW, gamedataEquipmentArea.CardiovascularSystemCW, gamedataEquipmentArea.IntegumentarySystemCW, gamedataEquipmentArea.ImmuneSystemCW, gamedataEquipmentArea.LegsCW, gamedataEquipmentArea.HandsCW, gamedataEquipmentArea.MusculoskeletalSystemCW];
    let open: array<Int32>;
    let total: array<Int32>;
    let next: array<Int32>;
    for area in areas {
      let exists = this.m_ctx.equip.GetEquipAreaIndex(area) >= 0;
      ArrayPush(open, exists ? this.SlotsAfterPerks(area) : 0);
      ArrayPush(total, exists ? this.m_ctx.equip.GetNumberOfSlots(area, true) : 0);
      ArrayPush(next, 0);
    }

    // Smart weapons only lock on through a Smart Link, so a build carrying one takes it first.
    let hands = ArrayFindFirst(areas, gamedataEquipmentArea.HandsCW);
    if this.m_kit.smart && hands >= 0 && open[hands] > 0 {
      let link = [n"SmartLink"];
      let item = this.Best(gamedataEquipmentArea.HandsCW, link, true);
      if ItemID.IsValid(item) {
        this.Place(gamedataEquipmentArea.HandsCW, 0, item);
        next[hands] = 1;
      } else {
        ArrayPush(this.m_draft.notes, "V's Smart weapons won't lock on without a Smart Link, and none fits this build.");
      }
    }

    while true {
      let best = -1;
      let bestArea = -1;
      let bestScore = -1.0;
      let i = 0;
      while i < ArraySize(this.m_stock.cyberware) {
        let data = this.m_stock.cyberware[i];
        let id = data.GetID();
        let a = ArrayFindFirst(areas, EquipmentSystem.GetEquipAreaType(id));
        if a >= 0 && next[a] < open[a] && this.m_cyberScores[i] > bestScore && this.CanUse(id, data, areas[a]) {
          bestScore = this.m_cyberScores[i];
          best = i;
          bestArea = a;
        }
        i += 1;
      }
      if best < 0 {
        break;
      }
      let item = this.m_stock.cyberware[best].GetID();
      this.Place(areas[bestArea], next[bestArea], item);
      next[bestArea] += 1;
      if ArraySize(this.m_draft.chrome) < 3 {
        ArrayPush(this.m_draft.chrome, HotswapGear.DisplayName(this.m_ctx, item));
      }
    }

    let a = 0;
    while a < ArraySize(areas) {
      let slot = next[a];
      while slot < total[a] {
        this.PlaceEmpty(areas[a], slot);
        slot += 1;
      }
      a += 1;
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
    this.CheckRequired(item);
    if ItemID.IsValid(item) {
      this.Place(area, 0, item);
      ArrayPush(this.m_draft.uses, HotswapGear.DisplayName(this.m_ctx, item));
      if EquipmentSystem.IsItemCyberdeck(item) {
        this.LoadDeck(item);
      }
    }
  }

  // Nearly every build is worth recommending from whatever V owns. The exception is one that can't
  // work at all without a piece V can't use, like a netrunner with nothing to hack with. That one
  // says what it needs and isn't made.
  private func CheckRequired(system: ItemID) -> Void {
    let needed = this.m_type.requires;
    if ArraySize(needed) == 0 || (ItemID.IsValid(system) && ArrayContains(needed, this.Type(system))) {
      return;
    }
    let owned = this.Strongest(gamedataEquipmentArea.SystemReplacementCW, needed, true);
    this.m_draft.blocker = ItemID.IsValid(owned)
      ? HotswapText.RequiredUnusable(this.m_type.name, this.m_type.requiresName, HotswapGear.DisplayName(this.m_ctx, owned))
      : HotswapText.RequiredMissing(this.m_type.name, this.m_type.requiresName);
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
    // No arms this build wants: V keeps the arms on now, and the build says so.
    let current = HotswapGear.Canon(this.m_ctx, area, HotswapGear.Raw(this.m_ctx, area, 0));
    if ItemID.IsValid(current) {
      this.m_bag.Claim(current);
      this.m_used += this.DraftCost(current);
      this.m_draft.Add(HotswapKindGear(), HotswapNames.OfArea(area), 0, current);
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
      let shard = TweakDBInterface.GetCName(ItemID.GetTDBID(id) + t".shardType", n"");
      let score = HotswapKnowledge.HackPriority(this.m_type.id, shard) * 10.0
        + HotswapRecommender.QualityRank(RPGManager.GetItemQualityFromRecord(record));
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

  // What a weapon is for the build matters most: its kind, its tech, and for a quiet build whether it
  // is silenced. Damage and grade only choose between weapons that suit it equally. Raw damage alone
  // would hand a stealth build the loudest gun V owns.
  private func WeaponScore(item: ItemID, data: wref<gameItemData>) -> Float {
    let record = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(item));
    if !IsDefined(record) {
      return 0.0;
    }
    let evolution = IsDefined(record.Evolution()) ? record.Evolution().Type() : gamedataWeaponEvolution.Invalid;
    let fit = this.m_type.WeaponFit(RPGManager.GetItemType(item), evolution, this.Quietness(item));
    if fit <= 0.0 {
      return 0.0;
    }
    let dps = this.m_stock.maxDps > 0.0 ? data.GetStatValueByType(gamedataStatType.EffectiveDPS) / this.m_stock.maxDps : 0.0;
    let iconic = RPGManager.IsItemIconic(data) ? 8.0 : 0.0;
    return fit * 100.0 + dps * 25.0 + HotswapRecommender.Rank(data) * 2.0 + iconic;
  }

  // 1 for a silenced weapon: built in (the record's Silenced tag) or with a silencer on its muzzle. A
  // bit less for one that takes a silencer V owns, since the build will fit it.
  private func Quietness(item: ItemID) -> Float {
    let data = this.m_ctx.ItemData(item);
    if IsDefined(data) && data.HasTag(n"Silenced") {
      return 1.0;
    }
    let muzzle = t"AttachmentSlots.PowerModule";
    let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, item);
    for slot in slots {
      if slot.slotID == muzzle {
        if Equals(slot.status, ESlotState.Taken) && HotswapRecommender.IsSilencer(slot.installedPart) {
          return 1.0;
        }
        for part in this.m_stock.parts {
          if HotswapRecommender.IsSilencer(part.GetID()) && HotswapRecommender.WeaponLists(item, muzzle, ItemID.GetTDBID(part.GetID())) {
            return 0.8;
          }
        }
      }
    }
    return 0.0;
  }

  public static func IsSilencer(part: ItemID) -> Bool {
    let record = RPGManager.GetItemRecord(part);
    return IsDefined(record) && record.TagsContains(n"Silenced");
  }

  // Scopes and muzzles only go on the weapons whose record lists them for that slot, as the game's own
  // mod screen checks (GetPlayerInventoryPartsForItemRef).
  public static func WeaponLists(weapon: ItemID, slot: TweakDBID, part: TweakDBID) -> Bool {
    let record = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weapon));
    if !IsDefined(record) {
      return false;
    }
    let lists: array<wref<SlotItemPartListElement_Record>>;
    record.SlotPartList(lists);
    for list in lists {
      if IsDefined(list.Slot()) && list.Slot().GetID() == slot {
        let entries: array<wref<ItemPartListElement_Record>>;
        list.ItemPartList(entries);
        for entry in entries {
          if IsDefined(entry.Item()) && entry.Item().GetID() == part {
            return true;
          }
        }
      }
    }
    return false;
  }

  // A draft has its own attributes, so V's current ones say nothing about what it can wield. While
  // surveying, the draft's aren't settled yet, so only what can never change counts.
  private func Wieldable(data: wref<gameItemData>, surveying: Bool) -> Bool {
    if this.m_ctx.Stat(gamedataStatType.Level) < Cast<Float>(FloorF(data.GetStatValueByType(gamedataStatType.Level))) {
      return false;
    }
    return surveying ? !RPGManager.IsItemBroken(data) : this.MeetsRequirements(data);
  }

  // best of what's left, limited to melee or to ranged if asked. 0 is either, 1 melee, 2 ranged.
  private func BestWeapon(kind: Int32, surveying: Bool) -> ItemID {
    let best = ItemID.None();
    let bestScore = 0.0;
    for data in this.m_stock.weapons {
      let id = data.GetID();
      if !this.m_bag.IsClaimed(id) && (kind == 0 || Equals(kind == 1, WeaponObject.IsMelee(id))) && this.Wieldable(data, surveying) {
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
    let order = [2, 1, 0];
    if this.m_type.id == 1 || (this.m_type.id == 2 && this.m_kit.blunt) {
      order = [1, 2, 0];
    }
    for kind in order {
      let item = ArraySize(picks) < open ? this.BestWeapon(kind, false) : ItemID.None();
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
    this.ChooseMods(picks);
    for left in [EnumInt(WeaponSlot.LeftSlot_1), EnumInt(WeaponSlot.LeftSlot_2), EnumInt(WeaponSlot.LeftSlot_3)] {
      if HotswapGear.SlotExists(this.m_ctx, area, left) {
        this.PlaceEmpty(area, left);
      }
    }
    this.m_fitWeapons = (ArraySize(picks) * 35) / 3;
  }

  // ---- Weapon mods ------------------------------------------------------------------------------

  // Each mod slot on the build's weapons gets the best mod V has for it: loose in the inventory, or
  // already on one of these weapons. A mod on a weapon the build doesn't use stays where it is.
  private func ChooseMods(picks: array<ItemID>) -> Void {
    let pool: array<ItemID>;
    for data in this.m_stock.parts {
      ArrayPush(pool, data.GetID());
    }
    for weapon in picks {
      let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, weapon);
      for slot in slots {
        if Equals(slot.status, ESlotState.Taken) && HotswapGear.IsTrackedPart(weapon, slot.slotID, slot.innerItemData) {
          ArrayPush(pool, slot.installedPart);
        }
      }
    }
    let taken: array<ItemID>;
    for weapon in picks {
      let slots = ItemModificationSystem.GetAllSlots(this.m_ctx.player, weapon);
      for slot in slots {
        if HotswapGear.IsTrackedPart(weapon, slot.slotID, slot.innerItemData) {
          let here = Equals(slot.status, ESlotState.Taken) ? slot.installedPart : ItemID.None();
          let best = ItemID.None();
          let bestScore = 0.0;
          for part in pool {
            if !ArrayContains(taken, part) && this.ModFits(weapon, part, slot.slotID, part == here) {
              let score = this.ModScore(part);
              if score > bestScore {
                bestScore = score;
                best = part;
              }
            }
          }
          if ItemID.IsValid(best) {
            ArrayPush(taken, best);
            this.m_draft.AddPart(weapon, slot.slotID, best);
            this.m_draft.mods += 1;
          }
        }
      }
    }
  }

  // The game's own rules for a mod on a weapon: the mod lists the slot as a place it goes, scopes and
  // muzzles must be listed by the weapon, and a mod can't be of a higher grade than the weapon. A mod
  // already in that slot is allowed to stay where it is.
  private func ModFits(weapon: ItemID, part: ItemID, slot: TweakDBID, alreadyThere: Bool) -> Bool {
    if alreadyThere {
      return true;
    }
    let record = RPGManager.GetItemRecord(part);
    if !IsDefined(record) {
      return false;
    }
    let placements: array<wref<AttachmentSlot_Record>>;
    record.PlacementSlots(placements);
    let placed = false;
    for placement in placements {
      if placement.GetID() == slot {
        placed = true;
      }
    }
    if !placed {
      return false;
    }
    if (slot == t"AttachmentSlots.PowerModule" || slot == t"AttachmentSlots.Scope")
      && !HotswapRecommender.WeaponLists(weapon, slot, ItemID.GetTDBID(part)) {
      return false;
    }
    let weaponData = this.m_ctx.ItemData(weapon);
    let chimera = Equals(TweakDBInterface.GetCName(ItemID.GetTDBID(part) + t".modType", n""), n"chimera_mod");
    if !chimera && IsDefined(weaponData)
      && this.PartGrade(part) > HotswapRecommender.QualityRank(RPGManager.GetItemDataQuality(weaponData)) {
      return false;
    }
    return true;
  }

  private func PartGrade(part: ItemID) -> Float {
    let data = this.m_ctx.ItemData(part);
    if IsDefined(data) {
      return HotswapRecommender.QualityRank(RPGManager.GetItemDataQuality(data));
    }
    let record = RPGManager.GetItemRecord(part);
    if IsDefined(record) && IsDefined(record.Quality()) {
      let rank = HotswapRecommender.QualityRank(record.Quality().Type());
      if rank > 0.0 {
        return rank;
      }
    }
    return 3.0;
  }

  // A mod's worth to this build: its grade, and what it changes, read from the stats on its record.
  // Each kind of effect counts once, so a mod isn't worth more for listing more stats. A silencer is
  // worth a lot to a quiet build and less than nothing to a loud one.
  private func ModScore(part: ItemID) -> Float {
    let record = RPGManager.GetItemRecord(part);
    if !IsDefined(record) {
      return 0.0;
    }
    let score = 1.0 + this.PartGrade(part) * 2.0;
    let stats: array<wref<StatModifier_Record>>;
    record.StatModifiers(stats);
    let packages: array<wref<GameplayLogicPackage_Record>>;
    record.OnAttach(packages);
    for package in packages {
      let more: array<wref<StatModifier_Record>>;
      package.Stats(more);
      for stat in more {
        ArrayPush(stats, stat);
      }
    }
    let counted: array<Int32>;
    for stat in stats {
      if IsDefined(stat) && IsDefined(stat.StatType()) {
        let kind = HotswapRecommender.EffectKind(stat.StatType().StatType());
        if kind >= 0 && !ArrayContains(counted, kind) {
          ArrayPush(counted, kind);
          score += this.Interest(kind);
        }
      }
    }
    if record.TagsContains(n"Silenced") {
      score += this.m_type.wants.quiet * 3.0;
    }
    return score;
  }

  // The kind of effect a stat is, by the name the game gives it.
  private static func EffectKind(stat: gamedataStatType) -> Int32 {
    let name = NameToString(EnumValueToName(n"gamedataStatType", Cast<Int64>(EnumInt(stat))));
    if StrContains(name, "Crit") || StrContains(name, "Headshot") {
      return 0;
    }
    if StrContains(name, "Range") || StrContains(name, "Zoom") {
      return 1;
    }
    if StrContains(name, "Reload") || StrContains(name, "Magazine") || StrContains(name, "Recoil")
      || StrContains(name, "Spread") || StrContains(name, "Aim") || StrContains(name, "Sway") || StrContains(name, "Handling") {
      return 2;
    }
    if StrContains(name, "Smart") {
      return 3;
    }
    if StrContains(name, "Charge") {
      return 4;
    }
    if StrContains(name, "AttackSpeed") || StrContains(name, "Stamina") || StrContains(name, "Bleed") {
      return 5;
    }
    if StrContains(name, "Damage") || StrContains(name, "Penetration") || StrContains(name, "Armor") {
      return 6;
    }
    return -1;
  }

  private func Interest(kind: Int32) -> Float {
    let wants = this.m_type.wants;
    switch kind {
      case 0:
        return wants.crit;
      case 1:
        return wants.range;
      case 2:
        return wants.handling;
      case 3:
        return wants.smart;
      case 4:
        return wants.charge;
      case 5:
        return wants.melee;
      default:
        return wants.damage;
    }
  }
}
