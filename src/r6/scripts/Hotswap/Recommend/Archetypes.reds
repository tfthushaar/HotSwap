// Hotswap - the five kinds of build the engine can make.
//
// An archetype is a direction, not a recipe. It names no items and no perks, and it doesn't say how
// to spend a single point beyond the attribute that makes it what it is. What it does say is what it
// values: which kinds of weapon, whether being quiet matters, and which effects it wants from a mod.
// The engine reads what V owns against that and works out the rest, so two players never get the
// same build unless they own the same things.

// What a build wants from a weapon mod. Each is a weight on the kind of stat a mod changes, read from
// the mod's own record (HotswapRecommender.ModScore).
public class HotswapInterests {
  public let crit: Float;       // crit chance and damage, headshots
  public let range: Float;      // effective range, zoom
  public let handling: Float;   // reload, magazine, recoil, spread, aiming
  public let smart: Float;      // smart targeting
  public let charge: Float;     // charge time and charged shots
  public let melee: Float;      // attack speed, stamina, bleeding
  public let damage: Float;     // raw damage and armor penetration
  public let quiet: Float;      // being unheard: silencers. Below zero for builds that want noise

  public static func Make(crit: Float, range: Float, handling: Float, smart: Float, charge: Float, melee: Float, damage: Float, quiet: Float) -> ref<HotswapInterests> {
    let self = new HotswapInterests();
    self.crit = crit;
    self.range = range;
    self.handling = handling;
    self.smart = smart;
    self.charge = charge;
    self.melee = melee;
    self.damage = damage;
    self.quiet = quiet;
    return self;
  }
}

public class HotswapArchetype {
  public let id: Int32;
  public let name: String;
  public let letter: String;
  public let blurb: String;
  public let main: gamedataStatType;                // the attribute that makes it this kind of build
  public let lean: array<gamedataStatType>;         // only settles what V's gear leaves even
  public let systems: array<CName>;                 // cyberwareType wanted for the operating system
  public let arms: array<CName>;                    // cyberwareType wanted for the arms
  public let requires: array<CName>;                // operating systems it can't work at all without
  public let requiresName: String;
  public let wants: ref<HotswapInterests>;

  // How well a weapon suits this build. quiet is 1 for a silenced weapon, a little less for one V can
  // silence with a muzzle V owns, and 0 for a loud one. A silencer only counts on a weapon the build
  // would carry anyway: it makes a good weapon better, not a wrong one right.
  public func WeaponFit(type: gamedataItemType, evolution: gamedataWeaponEvolution, quiet: Float) -> Float {
    let fit = this.WeaponKind(type, evolution);
    if fit <= 0.0 {
      return 0.0;
    }
    return MaxF(0.05, fit + quiet * this.wants.quiet * 0.15);
  }

  private func WeaponKind(type: gamedataItemType, evolution: gamedataWeaponEvolution) -> Float {
    switch this.id {
      case 0:
        if Equals(evolution, gamedataWeaponEvolution.Smart) {
          return 1.0;
        }
        return HotswapArchetype.Among(type, [gamedataItemType.Wea_Handgun, gamedataItemType.Wea_SubmachineGun, gamedataItemType.Wea_Revolver]) ? 0.4 : 0.0;
      case 1:
        if HotswapArchetype.IsBlade(type) {
          return 1.0;
        }
        if Equals(type, gamedataItemType.Wea_SubmachineGun) {
          return 0.6;
        }
        return Equals(type, gamedataItemType.Wea_Knife) ? 0.4 : 0.0;
      case 2:
        if HotswapArchetype.Among(type, [gamedataItemType.Wea_Shotgun, gamedataItemType.Wea_ShotgunDual, gamedataItemType.Wea_LightMachineGun, gamedataItemType.Wea_HeavyMachineGun, gamedataItemType.Wea_Hammer, gamedataItemType.Wea_TwoHandedClub, gamedataItemType.Wea_OneHandedClub]) {
          return 1.0;
        }
        if Equals(type, gamedataItemType.Wea_Axe) {
          return 0.6;
        }
        return Equals(type, gamedataItemType.Wea_AssaultRifle) ? 0.3 : 0.0;
      case 3:
        if HotswapArchetype.Among(type, [gamedataItemType.Wea_PrecisionRifle, gamedataItemType.Wea_SniperRifle, gamedataItemType.Wea_Knife, gamedataItemType.Wea_Axe]) {
          return 0.8;
        }
        return HotswapArchetype.Among(type, [gamedataItemType.Wea_Handgun, gamedataItemType.Wea_Revolver]) ? 0.6 : 0.0;
      default:
        if Equals(evolution, gamedataWeaponEvolution.Tech) || Equals(type, gamedataItemType.Wea_GrenadeLauncher) {
          return 1.0;
        }
        return Equals(type, gamedataItemType.Wea_AssaultRifle) ? 0.3 : 0.0;
    }
  }

  public static func IsBlade(type: gamedataItemType) -> Bool {
    return HotswapArchetype.Among(type, [gamedataItemType.Wea_Katana, gamedataItemType.Wea_LongBlade, gamedataItemType.Wea_ShortBlade, gamedataItemType.Wea_Sword, gamedataItemType.Wea_Machete, gamedataItemType.Wea_Chainsword]);
  }

  private static func Among(type: gamedataItemType, list: array<gamedataItemType>) -> Bool {
    return ArrayContains(list, type);
  }

  private static func Make(id: Int32, name: String, letter: String, blurb: String) -> ref<HotswapArchetype> {
    let self = new HotswapArchetype();
    self.id = id;
    self.name = name;
    self.letter = letter;
    self.blurb = blurb;
    return self;
  }

  public static func Count() -> Int32 = 5

  public static func Get(id: Int32) -> ref<HotswapArchetype> {
    let self: ref<HotswapArchetype>;
    switch id {
      case 0:
        self = HotswapArchetype.Make(id, "Netrunner", "N", "Quickhacks and smart guns, with Intelligence first.");
        self.main = gamedataStatType.Intelligence;
        self.lean = [gamedataStatType.TechnicalAbility, gamedataStatType.Cool];
        self.systems = [n"Cyberdeck"];
        self.requires = [n"Cyberdeck"];
        self.requiresName = "a cyberdeck";
        self.arms = [n"NanoWires"];
        self.wants = HotswapInterests.Make(1.0, 1.0, 1.0, 3.0, 0.0, 0.0, 1.0, 2.0);
        break;
      case 1:
        self = HotswapArchetype.Make(id, "Blade Dancer", "B", "Fast melee, built around a Sandevistan and Reflexes.");
        self.main = gamedataStatType.Reflexes;
        self.lean = [gamedataStatType.Cool, gamedataStatType.TechnicalAbility];
        self.systems = [n"Sandevistan"];
        self.arms = [n"MantisBlades", n"NanoWires"];
        self.wants = HotswapInterests.Make(2.0, 0.0, 1.0, 0.0, 0.0, 3.0, 1.0, 0.0);
        break;
      case 2:
        self = HotswapArchetype.Make(id, "Juggernaut", "J", "Walks through gunfire. Body first, with heavy guns and hard hits.");
        self.main = gamedataStatType.Strength;
        self.lean = [gamedataStatType.TechnicalAbility, gamedataStatType.Reflexes];
        self.systems = [n"Berserk"];
        self.arms = [n"StrongArms"];
        self.wants = HotswapInterests.Make(1.0, 0.0, 2.0, 0.0, 0.0, 2.0, 3.0, -2.0);
        break;
      case 3:
        self = HotswapArchetype.Make(id, "Ghost", "G", "Unseen and precise. Cool first, one quiet shot at a time.");
        self.main = gamedataStatType.Cool;
        self.lean = [gamedataStatType.Intelligence, gamedataStatType.Reflexes];
        self.systems = [n"Sandevistan", n"Cyberdeck"];
        self.arms = [n"NanoWires", n"MantisBlades"];
        self.wants = HotswapInterests.Make(3.0, 2.0, 1.0, 0.0, 0.0, 1.0, 1.0, 5.0);
        break;
      default:
        self = HotswapArchetype.Make(id, "Techie", "T", "Charged guns and explosives, with Technical Ability first.");
        self.main = gamedataStatType.TechnicalAbility;
        self.lean = [gamedataStatType.Reflexes, gamedataStatType.Cool];
        self.systems = [n"Sandevistan", n"Berserk", n"Cyberdeck"];
        self.arms = [n"ProjectileLauncher"];
        self.wants = HotswapInterests.Make(1.0, 1.0, 1.0, 0.0, 3.0, 0.0, 2.0, -1.0);
        break;
    }
    return self;
  }
}
