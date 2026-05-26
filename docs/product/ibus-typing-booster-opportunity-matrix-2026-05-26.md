# IBus Typing Booster Opportunity Matrix

Date: 2026-05-26

Scale: 1 is low, 5 is high. For effort and risk, lower is better.

| Idea | User value | Annoyance reduction | Privacy fit | Effort | Tech risk | Repo fit | Proofability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Calmer default suggestion pace | 4 | 5 | 5 | 1 | 2 | 5 | 5 | Shipped: new default tuning is Normal instead of Proactive. |
| Broader password-manager/private-field suppression | 5 | 4 | 5 | 1 | 1 | 5 | 5 | Shipped: added KeePassXC/KeePass/Keeper/NordPass/Proton Pass/RoboForm hints. |
| On-demand summon mode | 4 | 5 | 5 | 3 | 4 | 4 | 3 | Plan later. Must not overload Tab because Tab already accepts one word. |
| Learned suggestion removal | 3 | 4 | 5 | 3 | 2 | 4 | 4 | Good next step for Personal Capture / accepted-kept learning. |
| Explain why suggestions are off | 4 | 4 | 5 | 2 | 2 | 5 | 4 | Mostly present; improve wording after the current dirty branch settles. |
| Terminal disable parity | 5 | 5 | 5 | 1 | 1 | 5 | 5 | Already mostly present through denylist and command-line field suppression. Keep hardening. |
| Emoji/symbol one-shot lookup | 2 | 2 | 5 | 4 | 3 | 2 | 3 | Avoid for now. It widens scope beyond writing-assist proof. |
| Dense candidate picker | 2 | 1 | 4 | 5 | 5 | 1 | 2 | Avoid. It conflicts with SteadyType's calm floating suggestion stance. |
| Digits/F-key selection | 1 | 1 | 3 | 3 | 4 | 1 | 3 | Avoid. Public IBus docs warn digit selection makes typing numbers harder. |
| Optional cloud speech/AI | 2 | 1 | 1 | 5 | 5 | 1 | 2 | Avoid for beta. Keep app-owned local runtime. |

## Highest-Leverage Changes Picked

Shipped now:

- Calmer new-install default: reduces surprise candidate behavior.
- Password-manager/private-field suppression: adapts IBus terminal/password lessons to Mac Accessibility heuristics.

Held:

- On-demand summon mode: useful, but SteadyType must preserve Tab as next-word accept. A future shortcut could be "Show once" without taking over Tab.
- Learned suggestion removal: good, but needs a focused design around local Personal Capture and accepted-kept data.

