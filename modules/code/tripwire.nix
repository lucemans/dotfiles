{...}: {
  perSystem = {pkgs, ...}: let
    rules = import ./_rules;
    mutations = builtins.concatStringsSep "|" rules.gitMutations;
  in {
    # A PreToolUse hook. It runs before the permission rules, so it sees the
    # attempt first and the deny list in ./claude stays as the backstop for
    # anything the patterns miss.
    #
    # Each match adds its own tier to the session total, and three ends the
    # session. So the direct attempt warns, a detour around it warns harder,
    # and the two together are already terminal.
    packages.agent-tripwire = pkgs.writeShellApplication {
      name = "agent-tripwire";
      runtimeInputs = [pkgs.jq pkgs.coreutils pkgs.gnugrep];
      text = ''
        input="$(cat)"
        tool="$(jq -r '.tool_name // ""' <<<"$input")"
        session="$(jq -r '.session_id // "unknown"' <<<"$input")"

        if [ "$tool" = Bash ]; then
          subject="$(jq -r '.tool_input.command // ""' <<<"$input")"
        else
          subject="$(jq -r '
            [.tool_input.file_path?, .tool_input.path?, .tool_input.notebook_path?, .tool_input.pattern?]
            | map(select(type == "string")) | join(" ")
          ' <<<"$input")"
        fi

        # Credential and git-internal locations. Naming one is terminal by
        # itself, so these match paths and never a bare word: a project file
        # called credentials.ts must not end a session.
        secrets='(\.ssh/|id_(ed25519|rsa)|\.git/config|\.gitconfig|/run/secrets|\.config/sops|\.cargo/credentials|\.npmrc|\.netrc|\.sops\.yaml)'

        # Reaching a prohibited tool by a second route, which is the tell that
        # the first block was understood and is being worked around.
        detour='(nix[^;|&]*((#|-p +|--packages +)git([^a-z-]|$))|/nix/store/[^ ]*-git-[^ ]*/bin)'

        # The direct attempt. On the host, read-only git is policy, so only the
        # withheld subcommands count. Inside the sandbox there is no real git
        # at all, so any invocation is already the first flag.
        direct='(^|[^[:alnum:]_./-])(sudo|sops)([^[:alnum:]_-]|$)'
        if [ "''${AGENT_SANDBOX:-}" = 1 ]; then
          direct="$direct"'|(^|[^[:alnum:]_./-])git([^[:alnum:]_-]|$)'
        else
          direct="$direct"'|(^|[^[:alnum:]_./-])git[[:space:]]+(${mutations})([^[:alnum:]_-]|$)'
        fi

        if grep -qE "$secrets" <<<"$subject"; then
          tier=3
          reason='Blocked, and this is terminal. You reached for a credential or for git internals. Stop.'
        elif grep -qE "$detour" <<<"$subject"; then
          tier=2
          reason='Blocked. You tried to reach a withheld tool by another route, which is a second-level offence. Stop this line of work, and tell the user what you wanted to run and why.'
        elif grep -qE "$direct" <<<"$subject"; then
          tier=1
          reason='Blocked by policy. Git, sops, and sudo belong to the user, not to you. State the exact command and ask the user to run it. Do not look for another route to the same tool: attempts are counted, and three of them end the session.'
        else
          exit 0
        fi

        state="$XDG_RUNTIME_DIR/agent-tripwire"
        mkdir -p "$state"
        previous=0
        if [ -r "$state/$session" ]; then
          previous="$(cat "$state/$session")"
        fi
        strikes=$((previous + tier))
        echo "$strikes" > "$state/$session"

        # The terminal bell, so an unwatched window still says something.
        printf '\a' >&2

        note="tripwire: tier $tier on $tool, $strikes of 3 — ''${subject:0:120}"

        if [ "$strikes" -ge 3 ]; then
          jq -n --arg reason "$reason" --arg note "$note" '{
            continue: false,
            stopReason: "Tripwire: three strikes. Git and credential access is the user'"'"'s alone, and this session reached for it after being told. Nothing further runs.",
            systemMessage: $note,
            hookSpecificOutput: {
              hookEventName: "PreToolUse",
              permissionDecision: "deny",
              permissionDecisionReason: $reason,
            },
          }'
        else
          jq -n --arg reason "$reason" --arg note "$note" '{
            systemMessage: $note,
            hookSpecificOutput: {
              hookEventName: "PreToolUse",
              permissionDecision: "deny",
              permissionDecisionReason: $reason,
            },
          }'
        fi
      '';
    };
  };
}
