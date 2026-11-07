// Hotswap - version numbers.
//
// tools/package.ps1 writes these two lines. Nothing else should edit them.

public func HotswapVersion() -> String = "0.1.3"
public func HotswapVersionCode() -> Int32 = 103

// Which layout the saved data was written with. See Core/System.reds before changing it.
public func HotswapSchema() -> Int32 = 1
