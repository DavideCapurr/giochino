import Foundation

enum AgentNames {
    /// Process names (matched against `kp_proc.p_comm`, max 16 chars on Darwin) of
    /// known terminal AI coding agents. Add new ones here as the ecosystem grows.
    static let processNames: Set<String> = [
        "claude",
        "codex",
        "aider",
        "gemini",
        "cursor-agent",
        "goose",
        "block-goose",
        "amp",
        "opencode",
        "crush",
        "qwen"
    ]

    /// Folders that hold per-session transcripts written by known agents while
    /// they are responding. Each entry is a path relative to the user's home
    /// directory; the relay watches whichever the user grants access to.
    static let sessionDirectoryCandidates: [String] = [
        ".claude/projects",
        ".codex/sessions",
        ".aider"
    ]
}
