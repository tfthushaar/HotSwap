// Hotswap - Mod Settings page.
//
// Instant and free is the point, so that is the default. These exist for players who want the mod
// to cost them something. Mod Settings finds the fields through their runtime properties.

public class HotswapSettings {

  @runtimeProperty("ModSettings.mod", "Hotswap")
  @runtimeProperty("ModSettings.displayName", "Allow in combat")
  @runtimeProperty("ModSettings.description", "Lets a build swap during combat if it changes gear only. A build that changes perks or attributes is always refused in combat, because the game refuses it.")
  public let allowInCombat: Bool = false;

  @runtimeProperty("ModSettings.mod", "Hotswap")
  @runtimeProperty("ModSettings.displayName", "Seconds between swaps")
  @runtimeProperty("ModSettings.description", "How long V must wait before switching build again.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "600")
  @runtimeProperty("ModSettings.step", "5")
  public let cooldownSeconds: Int32 = 0;

  @runtimeProperty("ModSettings.mod", "Hotswap")
  @runtimeProperty("ModSettings.displayName", "Eddies per swap")
  @runtimeProperty("ModSettings.description", "What each swap costs.")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100000")
  @runtimeProperty("ModSettings.step", "500")
  public let eddieCost: Int32 = 0;

  public func Register() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  public func Unregister() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  public cb func OnModSettingsChange() -> Void {
  }
}
