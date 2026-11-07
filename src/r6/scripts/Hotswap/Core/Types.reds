// Hotswap - what a build is made of.
//
// READ THIS BEFORE CHANGING ANYTHING HERE.
//
// These two classes are written into the player's save. Two rules come from what they cost
// Cyberbane, and both are about the shape of the data, not the values:
//
//  1. No persisted class may hold an array. An array inside a persisted class comes back from a
//     save with a garbage buffer header, and the first push asks for gigabytes and crashes. The
//     engine does restore arrays held directly by a ScriptableSystem, so every row of every build
//     sits in one array on HotswapSystem and names the build it belongs to.
//
//  2. Adding or removing a persistent field throws away what was saved. That is why this layout is
//     generic: a new kind of data is a new kind of row, not a new field. The spare fields exist so
//     that a real need can be met without a wipe.

public func HotswapSlotCount() -> Int32 = 5

// A hidden sixth build: what V was wearing when the running swap started.
public func HotswapUndoBuild() -> Int32 = 5

public func HotswapKindGear() -> Int32 = 0       // key: area, value: slot, item: what sits there
public func HotswapKindPart() -> Int32 = 1       // host and attach: where, item: what is installed
public func HotswapKindPerk() -> Int32 = 2       // key: perk, value: level
public func HotswapKindAttribute() -> Int32 = 3  // key: stat, value: attribute level
public func HotswapKindHotkey() -> Int32 = 4     // key: hotkey, item: what it is bound to

public class HotswapEntry {
  public persistent let build: Int32;
  public persistent let kind: Int32;
  public persistent let key: CName;
  public persistent let value: Int32;
  public persistent let item: ItemID;
  public persistent let host: ItemID;
  public persistent let attach: TweakDBID;
  public persistent let spare: Int32;
}

public class HotswapHeader {
  public persistent let index: Int32;
  public persistent let used: Bool;
  public persistent let name: CName;
  public persistent let origin: Int32;    // 0 saved by the player, else recommended archetype + 1
  public persistent let spare: Int32;
}
