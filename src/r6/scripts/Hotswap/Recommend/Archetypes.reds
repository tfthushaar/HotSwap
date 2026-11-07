// Hotswap - the five kinds of build the engine can make.
//
// An archetype names no items and no individual perks. It holds preferences, and the engine turns
// those into a build from whatever V owns. Perks are chosen by branch of the tree, so the data here
// stays short and still follows the game if a patch moves a perk around.

public class HotswapArchetype {
  public let id: Int32;
  public let name: String;
  public let letter: String;
  public let blurb: String;
  public let attributes: array<gamedataStatType>;   // spent in this order
  public let branches: array<String>;               // perk name prefixes, best first
  public let systems: array<CName>;                 // cyberwareType wanted for the operating system
  public let arms: array<CName>;                    // cyberwareType wanted for the arms

  // How well a weapon suits this build, 0 to 1.
  public func WeaponAffinity(type: gamedataItemType, evolution: gamedataWeaponEvolution) -> Float {
    switch this.id {
      case 0:
        if Equals(evolution, gamedataWeaponEvolution.Smart) {
          return 1.0;
        }
        return HotswapArchetype.Among(type, [gamedataItemType.Wea_Handgun, gamedataItemType.Wea_SubmachineGun]) ? 0.4 : 0.0;
      case 1:
        if HotswapArchetype.Among(type, [gamedataItemType.Wea_Katana, gamedataItemType.Wea_LongBlade, gamedataItemType.Wea_ShortBlade, gamedataItemType.Wea_Sword, gamedataItemType.Wea_Machete, gamedataItemType.Wea_Chainsword, gamedataItemType.Wea_Knife]) {
          return 1.0;
        }
        return Equals(type, gamedataItemType.Wea_SubmachineGun) ? 0.7 : 0.0;
      case 2:
        if HotswapArchetype.Among(type, [gamedataItemType.Wea_Shotgun, gamedataItemType.Wea_ShotgunDual, gamedataItemType.Wea_LightMachineGun, gamedataItemType.Wea_HeavyMachineGun, gamedataItemType.Wea_Hammer, gamedataItemType.Wea_TwoHandedClub, gamedataItemType.Wea_OneHandedClub, gamedataItemType.Wea_Axe]) {
          return 1.0;
        }
        return Equals(type, gamedataItemType.Wea_AssaultRifle) ? 0.3 : 0.0;
      case 3:
        if HotswapArchetype.Among(type, [gamedataItemType.Wea_PrecisionRifle, gamedataItemType.Wea_SniperRifle, gamedataItemType.Wea_Handgun, gamedataItemType.Wea_Revolver, gamedataItemType.Wea_Knife]) {
          return 1.0;
        }
        return 0.0;
      default:
        if Equals(evolution, gamedataWeaponEvolution.Tech) || Equals(type, gamedataItemType.Wea_GrenadeLauncher) {
          return 1.0;
        }
        return Equals(type, gamedataItemType.Wea_AssaultRifle) ? 0.3 : 0.0;
    }
  }

  private static func Among(type: gamedataItemType, list: array<gamedataItemType>) -> Bool {
    return ArrayContains(list, type);
  }

  public func AttributeRank(stat: gamedataStatType) -> Int32 {
    return ArrayFindFirst(this.attributes, stat);
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
        self.attributes = [gamedataStatType.Intelligence, gamedataStatType.TechnicalAbility, gamedataStatType.Cool];
        self.branches = ["Intelligence_Central", "Intelligence_Left", "Intelligence_Right", "Intelligence_Inbetween", "Intelligence_Master", "Tech_Central", "Cool_Central", "Espionage_Central", "Espionage_Right", "Espionage_Left"];
        self.systems = [n"Cyberdeck"];
        self.arms = [n"NanoWires"];
        break;
      case 1:
        self = HotswapArchetype.Make(id, "Blade Dancer", "B", "Fast melee, built around a Sandevistan and Reflexes.");
        self.attributes = [gamedataStatType.Reflexes, gamedataStatType.Cool, gamedataStatType.TechnicalAbility];
        self.branches = ["Reflexes_Central", "Reflexes_Right", "Reflexes_Inbetween_Right", "Reflexes_Master", "Cool_Central", "Tech_Central", "Espionage_Central", "Espionage_Right", "Espionage_Left"];
        self.systems = [n"Sandevistan"];
        self.arms = [n"MantisBlades", n"NanoWires"];
        break;
      case 2:
        self = HotswapArchetype.Make(id, "Juggernaut", "J", "Walks through gunfire. Body first, with heavy guns and hard hits.");
        self.attributes = [gamedataStatType.Strength, gamedataStatType.TechnicalAbility, gamedataStatType.Reflexes];
        self.branches = ["Body_Central", "Body_Left", "Body_Right", "Body_Inbetween", "Body_Master", "Tech_Central", "Espionage_Central", "Espionage_Right", "Espionage_Left"];
        self.systems = [n"Berserk"];
        self.arms = [n"StrongArms"];
        break;
      case 3:
        self = HotswapArchetype.Make(id, "Ghost", "G", "Unseen and precise. Cool first, one shot at a time.");
        self.attributes = [gamedataStatType.Cool, gamedataStatType.Intelligence, gamedataStatType.Reflexes];
        self.branches = ["Cool_Right", "Cool_Left", "Cool_Central", "Cool_Inbetween", "Cool_Master", "Intelligence_Left", "Reflexes_Central", "Espionage_Left", "Espionage_Right", "Espionage_Central"];
        self.systems = [n"Sandevistan", n"Cyberdeck"];
        self.arms = [n"NanoWires", n"MantisBlades"];
        break;
      default:
        self = HotswapArchetype.Make(id, "Techie", "T", "Charged guns and explosives, with Technical Ability first.");
        self.attributes = [gamedataStatType.TechnicalAbility, gamedataStatType.Reflexes, gamedataStatType.Cool];
        self.branches = ["Tech_Left", "Tech_Right", "Tech_Central", "Tech_Inbetween", "Tech_Master", "Reflexes_Left", "Reflexes_Master", "Espionage_Central", "Espionage_Right", "Espionage_Left"];
        self.systems = [n"Sandevistan", n"Berserk", n"Cyberdeck"];
        self.arms = [n"ProjectileLauncher"];
        break;
    }
    return self;
  }
}
