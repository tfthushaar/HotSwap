// Hotswap - logging.
//
// Everything goes through one function, so a player's log can be read back after a bad swap. A swap
// writes a handful of lines and nothing runs on a timer, so there is no need for log levels.

public func HSLog(message: String) -> Void {
  FTLog(s"[Hotswap] \(message)");
}
