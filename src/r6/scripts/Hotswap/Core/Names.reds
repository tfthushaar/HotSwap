// Hotswap - moving between enums and the names stored in a save.
//
// Perks, areas and stats are saved by name. A game patch can reorder an enum, and a stored number
// would then quietly mean a different perk. A name either still means the same thing or stops
// resolving, and a name that stops resolving is skipped and reported.

public abstract class HotswapNames {

  public static func OfArea(area: gamedataEquipmentArea) -> CName {
    return EnumValueToName(n"gamedataEquipmentArea", Cast<Int64>(EnumInt(area)));
  }

  public static func ToArea(name: CName) -> gamedataEquipmentArea {
    let value = EnumValueFromName(n"gamedataEquipmentArea", name);
    if value < 0l || NotEquals(EnumValueToName(n"gamedataEquipmentArea", value), name) {
      return gamedataEquipmentArea.Invalid;
    }
    return IntEnum<gamedataEquipmentArea>(Cast<Int32>(value));
  }

  public static func OfPerk(perk: gamedataNewPerkType) -> CName {
    return EnumValueToName(n"gamedataNewPerkType", Cast<Int64>(EnumInt(perk)));
  }

  public static func PerkExists(name: CName) -> Bool {
    let value = EnumValueFromName(n"gamedataNewPerkType", name);
    return value >= 0l && Equals(EnumValueToName(n"gamedataNewPerkType", value), name);
  }

  public static func ToPerk(name: CName) -> gamedataNewPerkType {
    return IntEnum<gamedataNewPerkType>(Cast<Int32>(EnumValueFromName(n"gamedataNewPerkType", name)));
  }

  public static func OfStat(stat: gamedataStatType) -> CName {
    return EnumValueToName(n"gamedataStatType", Cast<Int64>(EnumInt(stat)));
  }

  public static func ToStat(name: CName) -> gamedataStatType {
    let value = EnumValueFromName(n"gamedataStatType", name);
    if value < 0l || NotEquals(EnumValueToName(n"gamedataStatType", value), name) {
      return gamedataStatType.Invalid;
    }
    return IntEnum<gamedataStatType>(Cast<Int32>(value));
  }

  public static func PerkCount() -> Int32 {
    return EnumInt(gamedataNewPerkType.Count);
  }

  public static func PerkAt(index: Int32) -> gamedataNewPerkType {
    return IntEnum<gamedataNewPerkType>(index);
  }

  // The five attributes a build sets. Stored under their stat names.
  public static func Attributes() -> array<gamedataStatType> {
    let list: array<gamedataStatType>;
    ArrayPush(list, gamedataStatType.Strength);
    ArrayPush(list, gamedataStatType.Reflexes);
    ArrayPush(list, gamedataStatType.TechnicalAbility);
    ArrayPush(list, gamedataStatType.Intelligence);
    ArrayPush(list, gamedataStatType.Cool);
    return list;
  }

  // All six perk trees, in the enum the perk system indexes by.
  public static func PerkTrees() -> array<gamedataAttributeDataType> {
    let list: array<gamedataAttributeDataType>;
    ArrayPush(list, gamedataAttributeDataType.BodyAttributeData);
    ArrayPush(list, gamedataAttributeDataType.ReflexesAttributeData);
    ArrayPush(list, gamedataAttributeDataType.TechnicalAbilityAttributeData);
    ArrayPush(list, gamedataAttributeDataType.IntelligenceAttributeData);
    ArrayPush(list, gamedataAttributeDataType.CoolAttributeData);
    ArrayPush(list, gamedataAttributeDataType.EspionageAttributeData);
    return list;
  }

  public static func IsCyberwareArea(area: gamedataEquipmentArea) -> Bool {
    switch area {
      case gamedataEquipmentArea.FrontalCortexCW:
      case gamedataEquipmentArea.SystemReplacementCW:
      case gamedataEquipmentArea.EyesCW:
      case gamedataEquipmentArea.MusculoskeletalSystemCW:
      case gamedataEquipmentArea.NervousSystemCW:
      case gamedataEquipmentArea.CardiovascularSystemCW:
      case gamedataEquipmentArea.ImmuneSystemCW:
      case gamedataEquipmentArea.IntegumentarySystemCW:
      case gamedataEquipmentArea.HandsCW:
      case gamedataEquipmentArea.ArmsCW:
      case gamedataEquipmentArea.LegsCW:
        return true;
      default:
        return false;
    }
  }

  public static func IsQuickArea(area: gamedataEquipmentArea) -> Bool {
    switch area {
      case gamedataEquipmentArea.Gadget:
      case gamedataEquipmentArea.QuickSlot:
      case gamedataEquipmentArea.Consumable:
        return true;
      default:
        return false;
    }
  }

  // Clothes are left out on purpose. Arm style, fists and quest slots belong to the game.
  public static func IsBuildArea(area: gamedataEquipmentArea) -> Bool {
    return HotswapNames.IsCyberwareArea(area)
      || HotswapNames.IsQuickArea(area)
      || Equals(area, gamedataEquipmentArea.Weapon)
      || Equals(area, gamedataEquipmentArea.CyberwareWheel);
  }
}
