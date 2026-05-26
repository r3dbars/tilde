# IBus Typing Booster Competitive Deep Dive

Date: 2026-05-26

Competitor: IBus Typing Booster

Sources:

- Official site: https://mike-fabian.github.io/ibus-typing-booster/
- User manual: https://mike-fabian.github.io/ibus-typing-booster/docs/user/
- GitHub repo: https://github.com/mike-fabian/ibus-typing-booster
- Key bindings: https://github.com/mike-fabian/ibus-typing-booster/blob/main/README.md
- Settings schema: https://github.com/mike-fabian/ibus-typing-booster/blob/main/org.freedesktop.ibus.engine.typing-booster.gschema.xml
- Main engine source: https://github.com/mike-fabian/ibus-typing-booster/blob/main/engine/hunspell_table.py
- Terminal detection source: https://github.com/mike-fabian/ibus-typing-booster/blob/main/engine/itb_util_gui.py

## Short Read

IBus Typing Booster is a Linux input-method autocomplete system. It is powerful because it sits directly in the typing path: it can predict words, transliterate, show emoji/symbol candidates, learn from typed text, and work across many apps.

That same position creates the main risk. Users get annoyed when the candidate list appears everywhere, when normal keys are captured, when typing slows down, or when secret/terminal input is exposed.

For SteadyType, the lesson is not "show more suggestions." The lesson is "make activation predictable, make private/off states obvious, and fail closed anywhere the field is even a little risky."

## Core Writing Loop

IBus Typing Booster runs as an IBus input method. The user types into a preedit buffer. The engine shows a lookup table of candidates from dictionaries, input methods, emoji data, and learned user input. The user commits a candidate with keys, mouse, or normal commit actions.

The manual and README describe default keyboard behavior:

- Space commits the preedit or selected candidate plus a space.
- Return commits the preedit or selected candidate.
- Tab either selects the next candidate or, when "Enable suggestions by Tab key" is enabled, summons the candidate list on demand.
- Esc cancels selection, closes related lookup, or clears preedit depending on state.
- F1-F9 commit numbered candidates.
- Ctrl+F1-F9 can remove learned candidates from the user database.

Source: README key binding table and manual.

## Delight Moments

- Correct top candidate: users can type less and keep their flow.
- Language help: Hunspell dictionaries and m17n input methods make it useful for multilingual typing.
- Emoji/symbol lookup: trigger characters can summon emoji/symbol suggestions without keeping emoji prediction always on.
- Learned personal words: local learned history improves predictions over generic dictionaries.
- Power controls: users can toggle off-the-record mode, direct input mode, emoji prediction, related lookup, and keybindings.

User praise appears in GitHub issue #533 and scattered forum/Reddit/HN discussion, but much of that praise is anecdotal.

## Annoyance Moments

- Always-on candidate UI can feel like a popup that "appears everywhere."
- Tab, digits, Space, and Return can conflict with normal typing expectations.
- Setup is hidden inside Linux input-source flows and can require restart/logout.
- Performance issues are deeply annoying because the product is in the keystroke path.
- App/toolkit differences create confusing bugs on Wayland, Chrome, terminals, Firefox, LibreOffice, and chat/terminal clients.

Complaint sources include:

- GitHub #893: learned junk / logging concerns.
- GitHub #26 and #37: password/terminal leakage concerns.
- GitHub #764 and #768: surrounding-text / Wayland behavior.
- GitHub #834, #33, #15: app-specific breakage.
- GitHub #889 and #732: startup/typing performance pain.
- Ask Ubuntu and Linux Uprising posts: setup and dictionary friction.

## Suppression And Privacy

The most relevant privacy pattern is explicit "Off the record" mode. The settings schema says learning from user input is disabled when it is on. It also exposes record modes, including a "Nothing" mode that records no input in the user database.

The engine also checks privacy-like states before recording. In source, recording is skipped for off-the-record mode, record mode "nothing", hidden input, and private input hints. It can also disable itself in terminal input when configured, and it blocks password/PIN input purposes.

Architecture inference: IBus has stronger field-purpose signals than a Mac Accessibility overlay in some contexts because input methods receive input purpose and hints. SteadyType should compensate with conservative app/field heuristics and proof gates.

## Local Vs Cloud

The default prediction path is local: dictionaries, m17n input methods, emoji data, and a local learned user database. Public docs also describe optional speech recognition through Google Cloud Speech-to-Text and optional AI chat / server-style integrations, which are outside the core typing booster loop.

SteadyType should keep the opposite default: app-owned local model, no user-managed server, no raw typed text unless explicitly opted in.

## Supported Surfaces And Breakage

IBus Typing Booster is designed for Linux apps through the input-method stack, not per-app adapters. That gives broad reach but creates toolkit-specific failure modes. Public issues mention:

- terminal/password leakage risk,
- Wayland surrounding-text problems,
- Chrome and browser quirks,
- Firefox popup placement,
- LibreOffice/autocorrect conflicts,
- HexChat Tab completion conflicts,
- Brave duplicate characters,
- language/input-method edge cases.

SteadyType should keep the proof-matrix approach instead of promising broad compatibility.

## Do Not Copy

Do not copy:

- source code,
- settings UI layout,
- candidate-list visual style,
- text/copy,
- icons/assets,
- Linux input-method trade dress,
- exact keybinding model.

Safe transferable ideas:

- on-demand suggestion mode,
- explicit private/off-the-record state,
- learned-item deletion controls,
- terminal/password suppression,
- app/context-specific disable rules,
- debug info that explains why suggestions are off,
- candidate removal / "do not suggest this again" concept.

## SteadyType Takeaways

1. Make new-install defaults calmer. Users should not feel like a popup suddenly owns typing.
2. Keep Tab narrow: one word only, only while a visible suggestion is valid.
3. Keep full accept separate and disabled in prompt/no-submit surfaces.
4. Treat password managers, terminal-like fields, search, URLs, forms, and private prompts as automatic off-record surfaces.
5. Expose pause/silence/why-off states plainly in Settings and Diagnostics.
6. Keep learning local and opt-in, and provide deletion/removal paths.
7. Keep app support proof-gated.
