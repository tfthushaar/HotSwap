// Hotswap - what each piece of cyberware is good for.
//
// Written from reading every cyberware type in the game's data (2.5): the stats its records change,
// the conditions its effects need (a melee weapon held, a kill, low health, being detected), and its
// tooltip text. Microrotors only speeds up attacks while a melee weapon is held (MeleeWeaponHeldPrereq),
// so it is a melee piece. Second Heart brings V back from death (HasSecondHeart), so it is worth having
// in almost any build.
//
// Each type gets a power, 0 to 10, for how much it helps any build, and a weight from 0 to 9 for each
// style of play it serves. A build has an interest in each style, and a piece is worth its power plus
// how well its styles match that build's interests. A type that isn't listed here, such as one a mod
// adds, still gets a fair middling power and is judged by its grade and attunement.

enum HotswapStyle {
  Melee = 0,
  Blades = 1,
  Blunt = 2,
  Ranged = 3,
  Precision = 4,
  Smart = 5,
  Tech = 6,
  Netrun = 7,
  Stealth = 8,
  Throwing = 9,
  Abilities = 10,
  Tank = 11,
  Sustain = 12,
  Mobility = 13,
}

public func HotswapStyleCount() -> Int32 = 14

public class HotswapKnowledge {
  private let m_types: array<CName>;
  private let m_power: array<Float>;
  private let m_weights: array<Float>;   // HotswapStyleCount() per type

  // Styles, in the order of the digits:
  //   melee, blades, blunt, ranged, precision, smart, tech, netrun, stealth, throwing, abilities,
  //   tank, sustain, mobility
  public static func Load() -> ref<HotswapKnowledge> {
    let k = new HotswapKnowledge();
    //                                   MBbRPSTNSTATSM
    // Frontal cortex
    k.Add(n"AntiVirus",                4, "00000002000100");
    k.Add(n"BioConductors",            6, "00000003000000");
    k.Add(n"BrainCapacityBooster",     4, "00000002000000");
    k.Add(n"ExDisk",                   5, "00000003000000");
    k.Add(n"FastAccessMemory",         5, "00000003000000");
    k.Add(n"MemoryBoost",              4, "00000002000000");
    k.Add(n"MemoryReplenishment",      6, "00000003000000");
    k.Add(n"RoboticCore",              3, "10010000000000");
    k.Add(n"SmartStorage",             3, "00000001000100");
    k.Add(n"SubdermalCoProcessor",     6, "00000000003000");
    k.Add(n"TimeBank",                 5, "00000000003000");
    k.Add(n"KerenziovBoostSystem",     4, "00010000031000");
    k.Add(n"ImprovedPerception",       4, "10011000000000");
    k.Add(n"LimbicSystemEnhancement",  4, "10011000000000");
    // Nervous system
    k.Add(n"DetectorRush",             3, "10000000000002");
    k.Add(n"ImprovedReaction",         3, "00000000002000");
    k.Add(n"Kerenzikov",               5, "00021000001001");
    k.Add(n"NeoFiber",                 5, "00000000000201");
    k.Add(n"OilDispenser",             4, "13000000020000");
    k.Add(n"ReflexRecorder",           5, "00000000000110");
    k.Add(n"SynapticAccelerator",      4, "00000000300000");
    k.Add(n"TroubleFinder",            3, "00000000200000");
    k.Add(n"TyrosineInjector",         4, "00002000200000");
    k.Add(n"VisualCortexSupport",      5, "10012000000000");
    // Cardiovascular system
    k.Add(n"BloodPump",                6, "00000000000030");
    k.Add(n"CatchMeIfYouCan",          3, "00000000000102");
    k.Add(n"CyberRotors",              5, "31100000000000");
    k.Add(n"DischargeConnector",       3, "00000030000000");
    k.Add(n"EnhancedBlood",            2, "00000000000010");
    k.Add(n"HealOnKill",               5, "00000000000020");
    k.Add(n"HealthMonitor",            7, "00000000000130");
    k.Add(n"IronLungs",                2, "10000000000000");
    k.Add(n"SecondHeart",             10, "00000000000230");
    k.Add(n"ShockAbsorber",            3, "00020000000000");
    k.Add(n"StaminaRegenBooster",      3, "30000000000000");
    k.Add(n"ViralVenom",               4, "21000000000000");
    // Integumentary system
    k.Add(n"AdaptiveStemCells",        5, "00000000000210");
    k.Add(n"BloodDepleter",            4, "00000000000300");
    k.Add(n"BoringPlating",            4, "00000000000300");
    k.Add(n"ChargeSystem",             4, "00011000000200");
    k.Add(n"Chiton",                   5, "00000000000310");
    k.Add(n"CogitoFrame",              4, "00000003000000");
    k.Add(n"ElectroshockMechanism",    3, "20000000000100");
    k.Add(n"NanoTechPlates",           4, "00020000000100");
    k.Add(n"OpticalCamo",              6, "00000000301000");
    k.Add(n"PainReductor",             6, "00000000000300");
    k.Add(n"PlatingGlitch",            3, "00010000001100");
    k.Add(n"ProximityReducer",         4, "20000000000200");
    k.Add(n"SuddenAid",                5, "00000000000220");
    k.Add(n"WeirdTankyPlating",        4, "10000000000200");
    k.Add(n"SubdermalArmor",           3, "00000000000200");
    k.Add(n"FireproofSkin",            1, "00000000000100");
    k.Add(n"GroundingPlating",         1, "00000000000100");
    k.Add(n"MetalCoveredSkin",         1, "00000000000100");
    k.Add(n"HeatUsingBooster",         1, "00000000000100");
    // Immune system
    k.Add(n"ResistancesBooster",       2, "00000000000100");
    k.Add(n"ReverseMetabolicEnhancer", 2, "00000000000100");
    k.Add(n"ReversePowerInductor",     2, "00000000000100");
    k.Add(n"ToxinCleanser",            2, "00000000000100");
    // Legs
    k.Add(n"BoostedTendons",           5, "10000000000003");
    k.Add(n"CatPaws",                  4, "00000000300001");
    k.Add(n"JenkinsTendons",           4, "10000000000003");
    k.Add(n"ReinforcedMuscles",        4, "10100000000002");
    k.Add(n"IconicJenkinsTendons",     5, "10000000000003");
    // Hands
    k.Add(n"GunStabilizer",            5, "00030000000000");
    k.Add(n"JointLock",                3, "00020000000000");
    k.Add(n"KnifeSharpener",           4, "02000000030000");
    k.Add(n"MicroGenerator",           3, "00020000000000");
    k.Add(n"PowerGrip",                4, "00030000000000");
    k.Add(n"SmartLink",                4, "00000401000000");
    // Musculoskeletal system
    k.Add(n"AgileJoints",              3, "00000000000200");
    k.Add(n"BionicJoints",             4, "00000000000300");
    k.Add(n"BoneMarrowCells",          4, "00000000000210");
    k.Add(n"CompilingSkeleton",        4, "00000003000000");
    k.Add(n"DenseMarrow",              5, "31100000000000");
    k.Add(n"Endoskeleton",             5, "00000000000210");
    k.Add(n"EnhancedTissue",           2, "10000000000000");
    k.Add(n"MicroVibrationsGenerator", 3, "20000000000000");
    k.Add(n"NeuroMatrix",              4, "00000003000000");
    k.Add(n"NoPainNoGain",             4, "00000000000210");
    k.Add(n"PainDistributor",          5, "10010000000110");
    k.Add(n"RapidMuscleNurish",        3, "00000000000002");
    k.Add(n"T1000",                    5, "00000000000300");
    k.Add(n"TitaniumInfusedBones",     1, "00000000000000");
    // Operating systems
    k.Add(n"Sandevistan",              7, "22002000003001");
    k.Add(n"Berserk",                  6, "30200000003200");
    k.Add(n"Cyberdeck",                6, "00000104100000");
    k.Add(n"CapacityBooster",          3, "00000000000000");
    // Arms
    k.Add(n"MantisBlades",             6, "34000000000001");
    k.Add(n"NanoWires",                6, "20000002000000");
    k.Add(n"StrongArms",               6, "30400000000100");
    k.Add(n"ProjectileLauncher",       5, "00020020000000");
    return k;
  }

  private func Add(type: CName, power: Int32, weights: String) -> Void {
    ArrayPush(this.m_types, type);
    ArrayPush(this.m_power, Cast<Float>(power));
    let i = 0;
    while i < HotswapStyleCount() {
      ArrayPush(this.m_weights, Cast<Float>(StringToInt(StrMid(weights, i, 1))));
      i += 1;
    }
  }

  // What a piece of this type is worth to a build with these interests.
  public func Worth(type: CName, interests: array<Float>) -> Float {
    let index = ArrayFindFirst(this.m_types, type);
    if index < 0 {
      return 4.0 * 3.0;
    }
    let worth = this.m_power[index] * 3.0;
    let base = index * HotswapStyleCount();
    let s = 0;
    while s < HotswapStyleCount() && s < ArraySize(interests) {
      worth += this.m_weights[base + s] * interests[s];
      s += 1;
    }
    return worth;
  }

  // How much a build wants each kind of quickhack, by the deck's shardType. Ghost hacks quietly,
  // the netrunner hacks to kill, anyone else with a deck wants control and information.
  public static func HackPriority(archetype: Int32, shard: CName) -> Float {
    let quiet = [n"Ping", n"Blind", n"MemoryWipe", n"CommsNoise", n"SystemCollapse", n"Whistle", n"CommsCallIn"];
    let lethal = [n"BlackWall", n"Overload", n"BrainMelt", n"Contagion", n"Overheat", n"SystemCollapse", n"Suicide", n"Madness"];
    let control = [n"Ping", n"Blind", n"Overload", n"LocomotionMalfunction", n"WeaponMalfunction", n"DisableCyberware", n"SystemCollapse"];
    let rank: Int32;
    if archetype == 0 {
      rank = ArrayFindFirst(lethal, shard);
    } else {
      if archetype == 3 {
        rank = ArrayFindFirst(quiet, shard);
      } else {
        rank = ArrayFindFirst(control, shard);
      }
    }
    return rank >= 0 ? Cast<Float>(10 - rank) : 1.0;
  }
}
