import Foundation
import AppKit

/// Service for installing the 'talky' command-line tool
@MainActor
class CLIInstallService: ObservableObject {
    /// Installation status
    enum InstallStatus: Equatable {
        case notInstalled
        case installed
        case needsUpdate
        case checking
    }

    @Published var status: InstallStatus = .checking
    @Published var installPath: String = "/usr/local/bin/talky"
    @Published var lastError: String?

    private let fileManager = FileManager.default

    /// The embedded CLI script
    private let cliScript = """
    #!/bin/bash
    #
    # talky - Command-line TTS using TalkyMcTalkface
    #
    # Usage:
    #   talky "Hello world"
    #   talky -v jerry-seinfeld "Hello world"
    #   echo "Hello" | talky
    #   talky --voices   # list available voices
    #

    SERVER="http://127.0.0.1:5111"
    VOICE=""
    TEXT=""
    QUEUE_ONLY=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--queue)
                QUEUE_ONLY=true
                shift
                ;;
            -v|--voice)
                VOICE="$2"
                shift 2
                ;;
            --voices)
                curl -s "$SERVER/voices" | python3 -c "
    import sys, json
    data = json.load(sys.stdin)
    print('  default: Chatterbox (Default)')
    for v in data.get('voices', []):
        print(f\\"  {v['id']}: {v['display_name']}\\")
    " 2>/dev/null || echo "Error: TalkyMcTalkface server not running"
                exit 0
                ;;
            -h|--help)
                echo "Usage: talky [OPTIONS] TEXT"
                echo ""
                echo "Options:"
                echo "  -v, --voice ID   Use specific voice"
                echo "  -q, --queue      Queue job and exit (app auto-plays)"
                echo "  --voices         List available voices"
                echo "  -h, --help       Show this help"
                echo ""
                echo "Examples:"
                echo "  talky \\"Hello world\\""
                echo "  talky -v jerry-seinfeld \\"Hello world\\""
                echo "  talky -q \\"Queue this\\"    # non-blocking"
                echo "  echo \\"Hello\\" | talky"
                exit 0
                ;;
            *)
                TEXT="$1"
                shift
                ;;
        esac
    done

    # Read from stdin if no text provided
    if [[ -z "$TEXT" ]]; then
        if [[ -t 0 ]]; then
            echo "Error: No text provided"
            echo "Usage: talky \\"Your text here\\""
            exit 1
        fi
        TEXT=$(cat)
    fi

    # Check server is running
    if ! curl -s "$SERVER/health" > /dev/null 2>&1; then
        echo "Error: TalkyMcTalkface server not running"
        echo "Start the TalkyMcTalkface app first"
        exit 1
    fi

    # Build request body
    if [[ -n "$VOICE" ]]; then
        BODY=$(printf '{"text": %s, "voice_id": "%s"}' "$(echo "$TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')" "$VOICE")
    else
        BODY=$(printf '{"text": %s}' "$(echo "$TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')")
    fi

    # Create job
    RESPONSE=$(curl -s -X POST "$SERVER/jobs" \\
        -H "Content-Type: application/json" \\
        -d "$BODY")

    JOB_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    if [[ -z "$JOB_ID" ]]; then
        echo "Error: Failed to create job"
        exit 1
    fi

    # Queue-only mode: exit immediately
    if [[ "$QUEUE_ONLY" == "true" ]]; then
        echo "Queued job $JOB_ID"
        exit 0
    fi

    # Poll for completion
    echo -n "Generating..."
    while true; do
        STATUS=$(curl -s "$SERVER/jobs/$JOB_ID" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

        case "$STATUS" in
            completed)
                echo " done!"
                break
                ;;
            failed)
                echo " failed!"
                exit 1
                ;;
            *)
                echo -n "."
                sleep 0.5
                ;;
        esac
    done

    # Download and play audio
    TMPFILE=$(mktemp /tmp/talky.XXXXXX.wav)
    curl -s "$SERVER/jobs/$JOB_ID/audio" -o "$TMPFILE"

    # Play audio
    afplay "$TMPFILE"

    # Cleanup
    rm -f "$TMPFILE"
    """

    init() {
        checkInstallation()
    }

    /// Check if CLI is installed
    func checkInstallation() {
        status = .checking

        if fileManager.fileExists(atPath: installPath) {
            // Check if it's our script by looking for the signature
            if let contents = try? String(contentsOfFile: installPath, encoding: .utf8),
               contents.contains("TalkyMcTalkface") {
                status = .installed
            } else {
                status = .notInstalled
            }
        } else {
            status = .notInstalled
        }
    }

    /// Install the CLI tool
    func install() {
        lastError = nil

        // Write script to temp file first
        let tempPath = NSTemporaryDirectory() + "talky_install"
        do {
            try cliScript.write(toFile: tempPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempPath)
        } catch {
            lastError = "Failed to prepare install: \(error.localizedDescription)"
            return
        }

        // Check if /usr/local/bin exists and try direct install
        let binDir = "/usr/local/bin"
        var needsAdmin = false

        if !fileManager.fileExists(atPath: binDir) {
            needsAdmin = true
        } else if !fileManager.isWritableFile(atPath: binDir) {
            needsAdmin = true
        }

        if needsAdmin {
            installWithAdminPrivileges(from: tempPath)
        } else {
            // Try direct copy
            do {
                if fileManager.fileExists(atPath: installPath) {
                    try fileManager.removeItem(atPath: installPath)
                }
                try fileManager.copyItem(atPath: tempPath, toPath: installPath)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installPath)
                status = .installed
            } catch {
                installWithAdminPrivileges(from: tempPath)
            }
        }

        // Cleanup temp file
        try? fileManager.removeItem(atPath: tempPath)
    }

    /// Install using admin privileges via AppleScript
    private func installWithAdminPrivileges(from sourcePath: String) {
        let script = """
        do shell script "mkdir -p /usr/local/bin && cp '\(sourcePath)' '\(installPath)' && chmod 755 '\(installPath)'" with administrator privileges
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)

            if let error = error {
                lastError = error[NSAppleScript.errorMessage] as? String ?? "Installation failed"
                status = .notInstalled
            } else {
                status = .installed
            }
        } else {
            lastError = "Failed to create install script"
        }
    }

    /// Uninstall the CLI tool
    func uninstall() {
        lastError = nil

        if !fileManager.fileExists(atPath: installPath) {
            status = .notInstalled
            return
        }

        // Try direct removal first
        do {
            try fileManager.removeItem(atPath: installPath)
            status = .notInstalled
        } catch {
            // Need admin privileges
            uninstallWithAdminPrivileges()
        }
    }

    /// Uninstall using admin privileges
    private func uninstallWithAdminPrivileges() {
        let script = """
        do shell script "rm -f '\(installPath)'" with administrator privileges
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)

            if let error = error {
                lastError = error[NSAppleScript.errorMessage] as? String ?? "Uninstall failed"
            } else {
                status = .notInstalled
            }
        } else {
            lastError = "Failed to create uninstall script"
        }
    }

    /// Open usage documentation in browser
    func showUsage() {
        if let url = URL(string: "http://127.0.0.1:5111/usage") {
            NSWorkspace.shared.open(url)
        }
    }
}
