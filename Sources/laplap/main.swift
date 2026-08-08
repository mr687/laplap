import AppKit
import Foundation

// e01s01 dispatch: help/usage (task 2), clean stub, cat mode end-to-end
// (task 6) with .accessory activation (no Dock icon).
let exitCode: Int32
switch ArgParser.parse(CommandLine.arguments) {
case .success(.help):
    print(ArgParser.usage)
    exitCode = 0
case .failure:
    FileHandle.standardError.write(Data((ArgParser.usage + "\n").utf8))
    exitCode = 2
case .success(.clean):
    // e02s01: clean mode reuses the e01 input lock, adds fullscreen black
    // overlays and a hidden cursor; CMDx6 unlock restores and exits 0.
    // AppKit must be initialized before touching activation policy.
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    exitCode = CleanMode(counter: UnlockCounter()).run()
case .success(.cat):
    // AppKit must be initialized before touching activation policy.
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    exitCode = CatMode(counter: UnlockCounter()).run()
}
exit(exitCode)
