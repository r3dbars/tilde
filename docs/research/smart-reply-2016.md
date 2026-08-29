# Smart Reply: Automated Response Suggestion for Email (Kannan, Kurach, Ravi, et al., KDD 2016)

**Source:** https://arxiv.org/abs/1606.04870
**License:** arXiv non-exclusive distribution license; KDD 2016 proceedings copy is separate.

## What it does (plain words)

Smart Reply is not ghost text. It is the three canned one-tap replies Gmail shows after you open a message. The useful part for Tilde is not the LSTM. It is the *trigger*: a second, cheaper model decides whether offering any reply is worth it, and a diversity layer refuses to show three paraphrases of "thanks."

## Method

About 25% of email replies were 20 tokens or shorter, which is why they tried one-tap responses at all. A seq2seq model scores a fixed response set. A feedforward trigger decides whether the incoming mail is a good candidate. Semantic clustering keeps the three shown replies apart in intent. They trained on aggregated data and shipped at Inbox-by-Gmail scale; the system assisted about 10% of mobile replies.

## Key findings

- Generation without a trigger is a product failure. Many messages should get silence.
- Diversity is a first-class filter. Three near-duplicates waste the glance.
- Privacy in their setting meant not inspecting individual messages during training reviews — still centralized training, not Tilde's on-device rule.
- Utility was measured as share of mobile replies assisted, not as retained characters.

## What Tilde should take from it

This is the industrial ancestor of H07 (skip inference) and of "silence is a feature." Smart Compose later put the same idea on every keystroke with a confidence threshold. Tilde already wants a cheap pre-inference skip. Smart Reply says that skip should run on *situation*, not only on token log-prob: some fields, apps, and message types should never wake the helper.

Do not import a three-choice reply chip. Tilde is one inline ghost. If we ever rank multiple internal candidates, the diversity filter is the transferable piece: do not spend decode budget on near-duplicates of the same phrase.

## Limits and caveats

Whole-message replies, mobile, cloud, canned set. This is not IMKit marked text and not continuous composition. The 10% assistance rate is not a Tilde target. Their trigger features would be illegal to log if they included message text; Tilde's skip features have to stay text-free (app class, timing, dismissal recency, Secure Event Input, exclusion).
