// ============================================================================
// main.swift - Entry point for ohr
// On-device speech-to-text from the command line.
// https://github.com/Arthur-Ficial/ohr
// ============================================================================

import Foundation
import OhrCore

// MARK: - Configuration

let version = buildVersion
let appName = "ohr"
let modelName = "apple-speechanalyzer"
let ohrDefaultPort = 11435

// MARK: - Exit Codes

let exitSuccess: Int32 = 0
let exitRuntimeError: Int32 = 1
let exitUsageError: Int32 = 2
let exitUnsupportedFormat: Int32 = 3
let exitFileNotFound: Int32 = 4
let exitTranscriptionFailed: Int32 = 5
let exitRateLimited: Int32 = 6

/// Map an OhrError to the appropriate exit code.
func exitCode(for error: OhrError) -> Int32 {
    switch error {
    case .unsupportedFormat:    return exitUnsupportedFormat
    case .fileNotFound:         return exitFileNotFound
    case .transcriptionFailed:  return exitTranscriptionFailed
    case .noSpeechDetected:     return exitTranscriptionFailed
    case .microphoneUnavailable: return exitRuntimeError
    case .rateLimited:          return exitRateLimited
    case .unsupportedLanguage:  return exitRuntimeError
    case .unknown:              return exitRuntimeError
    }
}

// MARK: - Signal Handling

signal(SIGINT) { _ in
    if isatty(STDOUT_FILENO) != 0 {
        FileHandle.standardOutput.write(Data("\u{001B}[0m".utf8))
    }
    FileHandle.standardError.write(Data("\n".utf8))
    _exit(130)
}

// MARK: - Argument Parsing

var args = Array(CommandLine.arguments.dropFirst())

// No args and no stdin pipe → print usage
if args.isEmpty {
    if isatty(STDIN_FILENO) == 0 {
        // Stdin pipe with no args → transcribe from stdin
        do {
            try await transcribeFromStdin(language: nil)
            exit(exitSuccess)
        } catch {
            let classified = OhrError.classify(error)
            printError("\(classified.cliLabel) \(classified.openAIMessage)")
            exit(exitCode(for: classified))
        }
    }
    printUsage()
    exit(exitUsageError)
}

// Parse flags - env vars provide defaults, CLI flags override
let env = ProcessInfo.processInfo.environment
var mode: String = "transcribe"
var cliLanguage: String? = env["OHR_LANGUAGE"]
var serverPort: Int = Int(env["OHR_PORT"] ?? "") ?? ohrDefaultPort
var serverHost: String = env["OHR_HOST"] ?? "127.0.0.1"
var serverCORS: Bool = false
var serverMaxConcurrent: Int = 5
var serverDebug: Bool = false
var serverAllowedOrigins: [String] = OriginValidator.defaultAllowedOrigins
var serverOriginCheckEnabled: Bool = true
var serverToken: String? = env["OHR_TOKEN"]
var serverTokenAuto: Bool = false
var serverPublicHealth: Bool = false
var showTimestamps: Bool = false
var filePaths: [String] = []

@MainActor
func nextArg(_ args: inout [String], _ flag: String) -> String {
    guard !args.isEmpty else {
        printError("\(flag) requires a value")
        exit(exitUsageError)
    }
    return args.removeFirst()
}

func parseAllowedOrigins(_ value: String) -> [String] {
    value.split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

while !args.isEmpty {
    let arg = args.removeFirst()
    switch arg {
    case "-h", "--help":
        printUsage()
        exit(exitSuccess)
    case "-v", "--version":
        print("\(appName) \(version)")
        exit(exitSuccess)
    case "--release":
        printRelease()
        exit(exitSuccess)
    case "--model-info":
        await printModelInfo()
        exit(exitSuccess)

    // Output
    case "-o", "--output":
        let fmt = nextArg(&args, arg)
        switch fmt {
        case "plain", "text": outputFormat = .plain
        case "json": outputFormat = .json
        case "srt": outputFormat = .srt
        case "vtt": outputFormat = .vtt
        default:
            printError("Unknown output format '\(fmt)'. Use: plain, json, srt, vtt")
            exit(exitUsageError)
        }
    case "--json":
        outputFormat = .json
    case "--srt":
        outputFormat = .srt
    case "--vtt":
        outputFormat = .vtt
    case "--timestamps":
        showTimestamps = true
    case "-q", "--quiet":
        quietMode = true
    case "--no-color":
        noColorFlag = true

    // Language
    case "-l", "--language":
        cliLanguage = nextArg(&args, arg)

    // Modes
    case "--listen":
        mode = "listen"
    case "--serve":
        mode = "serve"

    // Server options
    case "--port":
        guard let p = Int(nextArg(&args, arg)), p > 0 else {
            printError("--port requires a positive integer")
            exit(exitUsageError)
        }
        serverPort = p
    case "--host":
        serverHost = nextArg(&args, arg)
    case "--cors":
        serverCORS = true
    case "--allowed-origins":
        let extra = parseAllowedOrigins(nextArg(&args, arg))
        serverAllowedOrigins += extra
    case "--no-origin-check":
        serverOriginCheckEnabled = false
    case "--token":
        serverToken = nextArg(&args, arg)
    case "--token-auto":
        serverTokenAuto = true
    case "--public-health":
        serverPublicHealth = true
    case "--footgun":
        serverOriginCheckEnabled = false
        serverCORS = true
    case "--max-concurrent":
        guard let n = Int(nextArg(&args, arg)), n > 0 else {
            printError("--max-concurrent requires a positive integer")
            exit(exitUsageError)
        }
        serverMaxConcurrent = n
    case "--debug":
        serverDebug = true

    default:
        if arg.hasPrefix("-") {
            printError("Unknown option: \(arg)")
            printStderr("Run '\(appName) --help' for usage.")
            exit(exitUsageError)
        }
        // Positional argument = file path
        filePaths.append(arg)
    }
}

// MARK: - Mode Dispatch

switch mode {
case "listen":
    do {
        try await listenMicrophone(language: cliLanguage)
    } catch {
        let classified = OhrError.classify(error)
        printError("\(classified.cliLabel) \(classified.openAIMessage)")
        exit(exitCode(for: classified))
    }

case "serve":
    if serverTokenAuto && serverToken == nil {
        serverToken = UUID().uuidString
    }
    let config = ServerConfig(
        host: serverHost,
        port: serverPort,
        cors: serverCORS,
        maxConcurrent: serverMaxConcurrent,
        debug: serverDebug,
        allowedOrigins: serverAllowedOrigins,
        originCheckEnabled: serverOriginCheckEnabled,
        token: serverToken,
        tokenWasAutoGenerated: serverTokenAuto,
        publicHealth: serverPublicHealth
    )
    do {
        try await startServer(config: config)
    } catch {
        printError("Server failed: \(error.localizedDescription)")
        exit(exitRuntimeError)
    }

default:
    // Transcribe mode
    if filePaths.isEmpty {
        if isatty(STDIN_FILENO) == 0 {
            // Stdin pipe
            do {
                try await transcribeFromStdin(language: cliLanguage)
            } catch {
                let classified = OhrError.classify(error)
                printError("\(classified.cliLabel) \(classified.openAIMessage)")
                exit(exitCode(for: classified))
            }
        } else {
            printError("No audio file specified. Run '\(appName) --help' for usage.")
            exit(exitUsageError)
        }
    } else {
        for path in filePaths {
            do {
                try await transcribeFileCommand(path: path, language: cliLanguage, timestamps: showTimestamps)
            } catch {
                let classified = OhrError.classify(error)
                printError("\(classified.cliLabel) \(classified.openAIMessage)")
                exit(exitCode(for: classified))
            }
        }
    }
}

exit(exitSuccess)
