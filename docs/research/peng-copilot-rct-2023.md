# The Impact of AI on Developer Productivity (Peng, Kalliamvakou, Cihon & Demirer, 2023)

**Source:** https://arxiv.org/abs/2302.06590
**License:** arXiv non-exclusive distribution license.

## What it does (plain words)

A randomized experiment on a programming task: some developers got Copilot, some did not. The treated group finished the task about 55% faster on average. This is the "Copilot makes you faster" paper that product talks quoted. It is a task-time RCT, not an acceptance-rate study.

## Method

Recruit developers, give a standardized HTTP-server-in-JavaScript task, randomly assign Copilot access, measure time-to-done and success. Survey follow-ups asked about experience.

## Key findings

- Treated developers completed the task substantially faster (the widely cited figure is about 55%).
- Less experienced developers gained more.
- This is one task, in one language, with a stopwatch. It does not measure retained code after a week, or whether people understood what they accepted.

## What Tilde should take from it

Task-time RCTs are possible and they are not Tab rate. Tilde cannot run a 90-person lab RCT on Mail. The transferable discipline is: when we finally do live H01, the outcome is time-and-kept-characters, not "more Tabs."

Do not import 55% as a Tilde expectation. Completing a canned coding puzzle with a 12B-class cloud model is not finishing a sentence in Messages with Gemma 4 E2B.

This paper is also why Ziegler 2022 and the 2025 retained-character blog must be read together. Speed on a lab task can be real, and production metrics can still reward junk if you optimize the wrong proxy.

## Limits and caveats

Single task, self-selected developers, Copilot as it was in 2022–2023, no IMKit, no privacy-safe telemetry recipe. Success was "the task passed," not "the owner still wanted those characters."
