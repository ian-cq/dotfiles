#!/usr/bin/env python3
"""PreToolUse Bash guard for Claude Code profiles.

Ports the per-agent bash allow/deny globs that OpenCode expressed in agent
frontmatter. Claude Code agent frontmatter has no equivalent, so the rules live
here and are wired in through each profile's settings file.

Usage: guard.py <profile>   # profile: survey | autonomous
Reads the PreToolUse hook payload on stdin, emits a permissionDecision on stdout.
"""

import json
import re
import sys

# Segment separators. Every segment of a chained command is checked
# independently, so `kubectl get pods && rm -rf /` cannot slip through on the
# strength of its first segment.
SPLIT = re.compile(r"&&|\|\||;|\||\n")

# rtk is a transparent output filter (see CLAUDE.md) and CLAUDE.md tells agents
# to prefix every command with it, so strip it before matching.
PREFIX = re.compile(r"^(?:rtk|command|env|time|nice)\s+")

SURVEY_ALLOW = [
    r"kubectl\s+--context\s+twingate-dev-eks-api-server\s+(get|describe|logs|top)\b",
    r"helm\s+--kube-context\s+twingate-dev-eks-api-server\s+(list|status|get)\b",
    r"(cat|ls|find|grep|rg|wc|du|df|ps|curl|jq|head|tail|stat|aws|echo|pwd|which|sort|uniq|awk|column|date)\b",
]

# Destructive verbs that stay blocked even in autonomous mode.
AUTONOMOUS_DENY = [
    r"sudo\b",
    r"\brm\b",
    r"kubectl\b.*\bdelete\b",
    r"helm\b.*\b(delete|uninstall)\b",
    r"terraform\b.*\bdestroy\b",
    r"aws\b.*\bdelete-\w+",
]


def segments(command):
    for raw in SPLIT.split(command):
        seg = raw.strip()
        while True:
            stripped = PREFIX.sub("", seg, count=1)
            if stripped == seg:
                break
            seg = stripped
        if seg:
            yield seg


def decide(profile, command):
    if profile == "survey":
        for seg in segments(command):
            if not any(re.match(p, seg) for p in SURVEY_ALLOW):
                if re.match(r"(kubectl|helm)\b", seg):
                    return (
                        "deny",
                        "survey profile: kubectl/helm must target "
                        "--context twingate-dev-eks-api-server with a read-only "
                        f"verb (get/describe/logs/top). Blocked: {seg}",
                    )
                return (
                    "deny",
                    f"survey profile is read-only; command not on the allowlist: {seg}",
                )
        # Every segment matched — pre-approve, matching the OpenCode survey
        # agent, which allowed these outright rather than prompting.
        return ("allow", "survey profile allowlist")

    if profile == "autonomous":
        for seg in segments(command):
            for pattern in AUTONOMOUS_DENY:
                if re.search(pattern, seg):
                    return (
                        "deny",
                        f"autonomous profile blocks destructive commands. Blocked: {seg}",
                    )
        return None

    return None


def main():
    profile = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    command = (payload.get("tool_input") or {}).get("command", "")
    if not command:
        return
    verdict = decide(profile, command)
    if not verdict:
        return
    decision, reason = verdict
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": decision,
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
