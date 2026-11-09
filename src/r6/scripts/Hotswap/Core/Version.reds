// Hotswap - version numbers.
//
// tools/package.ps1 writes these two lines. Nothing else should edit them.

public func HotswapVersion() -> String = "1.1.0"
public func HotswapVersionCode() -> Int32 = 10100

// Which layout the saved data was written with. See Core/System.reds before changing it.
public func HotswapSchema() -> Int32 = 1
