# MVP Plan

## Goal

Build the smallest Mac autocomplete prototype that can prove or disprove the user experience.

The first prototype should feel like a quiet writing assist, not a chatbot.

## User Loop

1. User types in an allowed app.
2. App reads nearby text and cursor position.
3. Local model predicts a short continuation.
4. Suggestion appears near the cursor.
5. User presses `Tab` to accept the next word.
6. User presses backtick/tilde to accept the whole visible suggestion.
7. User presses `Esc` or keeps typing to dismiss/refresh.

## Prototype Milestones

### 1. Mac Plumbing

- menu bar app
- Accessibility onboarding
- frontmost app detection
- focused text element detection
- caret rectangle detection
- small floating panel

### 2. Insertion

- accept next word with `Tab`
- accept the whole visible suggestion with backtick/tilde
- dismiss with `Esc`
- insert through AX selected text when possible
- fall back to synthetic key events when safer for the target app
- keep clipboard fallback off unless a debug build explicitly opts in

### 3. Completion Engine

- start with a mock/static completion engine
- then use Qwen3.5 4B for real continuations
- target Apple Silicon / 16 GB as the first supported hardware profile
- ship an app-owned local runtime so users do not start a separate model server
- use MLX as the app-owned runtime
- keep the model warm while the app is active
- disable thinking/reasoning
- keep output to 2-8 words
- cap generation around 8-16 tokens
- keep normal typing passthrough immediate
- debounce or delay only suggestion requests and floating presentation
- hard cap latency target under 700ms for the first useful build

### 4. Private Beta

- test with 3-5 people
- log only local aggregate counters at first
- require explicit local opt-in for raw text traces or debug screenshots
- collect qualitative feedback manually

## Things To Watch

- Accessibility APIs vary a lot by app.
- Password fields and secure fields must suppress suggestions.
- Browser and Electron apps may need extra AX nudges.
- Clipboard fallback can annoy people if it corrupts clipboard state.
- True inline ghost text is much harder than a floating suggestion panel.
