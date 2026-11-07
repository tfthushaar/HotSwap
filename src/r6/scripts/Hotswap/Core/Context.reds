// Hotswap - the handful of game systems nearly every function needs, fetched once per operation.

public class HotswapContext {
  public let player: wref<PlayerPuppet>;
  public let game: GameInstance;
  public let ts: ref<TransactionSystem>;
  public let equip: ref<EquipmentSystemPlayerData>;
  public let dev: ref<PlayerDevelopmentData>;
  public let stats: ref<StatsSystem>;

  public static func Make(player: wref<PlayerPuppet>) -> ref<HotswapContext> {
    if !IsDefined(player) {
      return null;
    }
    let self = new HotswapContext();
    self.player = player;
    self.game = player.GetGame();
    self.ts = GameInstance.GetTransactionSystem(self.game);
    self.stats = GameInstance.GetStatsSystem(self.game);
    self.equip = EquipmentSystem.GetData(player);
    self.dev = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(self.equip) || !IsDefined(self.dev) {
      return null;
    }
    return self;
  }

  public func Stat(type: gamedataStatType) -> Float {
    return this.stats.GetStatValue(Cast<StatsObjectID>(this.player.GetEntityID()), type);
  }

  public func ItemData(item: ItemID) -> wref<gameItemData> {
    return this.ts.GetItemData(this.player, item);
  }
}
