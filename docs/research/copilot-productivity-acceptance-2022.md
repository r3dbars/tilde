# Productivity Assessment of Neural Code Completion (Ziegler, Kalliamvakou, Li, et al., MAPS 2022)

**Source:** https://doi.org/10.1145/3520312.3534864
**Later write-up:** Measuring GitHub Copilot's Impact on Productivity, CACM 2024, https://doi.org/10.1145/3633453
**License:** ACM; CACM version is the public long form. Link and attribute.

## What it does (plain words)

GitHub asked 2,631 Copilot users whether the tool made them more productive, then lined those answers up with IDE telemetry. They already recorded persistence — whether accepted code was still in the file 30 to 600 seconds later. The surprise: *acceptance rate* predicted how productive people *felt* better than retained characters did.

## Method

Preview users filled a SPACE-style survey. Events included shown, accepted, accepted characters, and persistence at several horizons, including "mostly unchanged." Metrics were normalized (accepted per shown, accepted per hour). They also published the aggregate dataset. Copilot's acceptance rate in the study was 27%, with more than 31 accepted completions per user per day. IntelliCode Compose had reported about 10% CTR in earlier online trials.

## Key findings

- Accepted-per-shown beat persistence and character-contribution metrics as a predictor of self-reported productivity.
- The productivity dimensions on the survey moved together, so they averaged them.
- Acceptance varied by language, time of day, and what the developer was trying to do.
- Persistence was the more "obviously correct" engineering metric and still lost to Tab rate as a *feeling* predictor.

## What Tilde should take from it

This paper does not refute RNKS. It explains why Tab is a tempting lie. People feel helped when they accept often. Copilot later learned (2025 blog) that optimizing that feeling produced short junk people deleted. Tilde has to hold both facts at once:

- Tab rate is a useful *diagnostic* for "did this feel like a suggestion worth taking?"
- Tab rate is a bad *promotion target* because it rewards the feeling, not the kept writing.
- Owner dogfood that says "this felt better" is the Ziegler metric. It cannot close H01–H04 until F03 exists.

The persistence instrumentation is the recipe for F03: keep 5s / 30s / segment horizons, and treat "mostly unchanged" as a second count if a cheap, text-free edit distance is possible. Do not import their survey as a ship gate.

## Limits and caveats

Code in an IDE, networked model, self-selected preview users, perceived productivity rather than task time or retained utility. The 2025 Copilot blog is the later product decision; this 2022 paper is the earlier measurement mistake that made that decision necessary. Tilde's online events must stay text-free, so we cannot copy their "mostly unchanged" check if it requires storing the completion.
