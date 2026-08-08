import Foundation

/// Hand-rolled CLI parsing (zero external deps). Accepts `cat`, `clean`,
/// `--help`; anything else is a usage error (main exits 2).
enum ArgParser {
    enum Mode: Equatable, Sendable {
        case cat
        case clean
        case help
    }

    struct ParseError: Error, Equatable {
        /// The offending argument, or nil when no mode argument was given.
        let argument: String?
    }

    static let usage = """
    Usage: laplap <mode>

    Modes:
      cat    Lock keyboard, trackpad, and mouse until Command is pressed 6 times within 10 seconds
      clean  Lock all input behind fullscreen black overlays; unlock with the same CMD×6 gesture

    Unlock: press Command 6 times within 10 seconds (CMD×6).
    Requires Accessibility permission to intercept input.

    Options:
      --help  Show this help

    Exit codes:
      0  Lock released (unlock gesture or signal) or help shown
      2  Usage error (no mode, or unknown mode)
      3  Accessibility permission not granted
    """

    /// Parses full argv (program name at index 0); only the first mode
    /// argument is considered.
    static func parse(_ arguments: [String]) -> Result<Mode, ParseError> {
        guard let argument = arguments.dropFirst().first else {
            return .failure(ParseError(argument: nil))
        }
        switch argument {
        case "cat":
            return .success(.cat)
        case "clean":
            return .success(.clean)
        case "--help":
            return .success(.help)
        default:
            return .failure(ParseError(argument: argument))
        }
    }
}
