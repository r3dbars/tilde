# Icebox

This is where proof lanes go when they are interesting but no longer the best
use of engineering time.

## Terminal Hosts

Status: parked, except the live Claude Code word-only lane.

Claude Code (`com.anthropic.claude-code`) graduated out of this icebox to a
default-on, word-only dogfood lane: marker-gated, Claude-detected, one-word
no-submit accepts with verified insertion and shell-command guarding, tracked in
the proof manifest as a yellow/partial host. The broader terminal hosts below
stay parked.

What is partly proved:

- Terminal and iTerm2 have bounded proof-mode rows for marker-gated,
  one-word Claude Code prompt accepts.
- Ghostty placement got better: the proof harness can sometimes anchor the
  suggestion to the real prompt row instead of stale terminal header text.
- The terminal-host adapter is intentionally virtual, marker-gated, and
  shell-command guarded. Normal, unmarked terminal sessions stay blocked.

What is not proved:

- Ghostty insertion transport is still not verified. Recent runs reached
  prompt-row suggestions and accept handling, then failed closed because the
  app-owned insertion sources did not mutate the disposable prompt.
- Proof does not show that normal shell prompts, command buffers,
  active agent output, or unmarked terminal sessions are safe.
- Terminal-host proof does not count as normal writing support or beta-safe app
  coverage, and full accept stays blocked.

Decision:

Park Ghostty and untested/unmarked terminal-host proof work until the core
writing apps feel good enough to justify broader host work. The live product
loop should spend engineering time on TextEdit, Notes, Obsidian, and other
boring writing fields first: suggestion usefulness, placement reliability,
speed, restraint, and clear "why quiet" behavior.

Do not spend another cycle trying to make Ghostty green unless the explicit goal
is terminal-host research. If that goal returns, the first proof target is still
verified one-word Ghostty insertion in a disposable no-submit prompt, not a beta
support claim.
