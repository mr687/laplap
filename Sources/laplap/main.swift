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
    // Parsed but no lock behavior in e01s01 (that is epic e02). Least-surprise
    // stub: clear message, exit 0.
    print("laplap clean: not implemented in this story (see epic e02)")
    exitCode = 0
case .success(.cat):
    // AppKit must be initialized before touching activation policy.
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    exitCode = CatMode(counter: UnlockCounter()).run()
}
exit(exitCode)
