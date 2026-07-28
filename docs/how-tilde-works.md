# How Tilde works (in plain language)

*Owner-written explainer, 2026-07-28. The four-employees model at the end is
close to the app's literal architecture — the canonical mental model.*

Right now there's a lot of AI jargon floating around, but Tilde doesn't need
you to become an AI researcher. It needs you to understand what each piece does.

Imagine you're building a baseball team. You don't need nine pitchers. You
need each player to have one job. Tilde works the same way.

## 1. The Language Model
The brain that guesses what you'll type next. Think of it like a friend
finishing your sentence. You type "I'll send that over" — it guesses "later
today." That's all it does. Examples: Gemma, Qwen, Llama. Different brains.

## 2. Context
Everything the brain gets to look at before making a guess. Instead of only
seeing "I'll send", it might also see the whole message you're replying to.
More context usually means better predictions.

## 3. Context Window
How much can the brain remember at once? Small: the last sentence. Large: the
last 20 pages. Autocomplete mostly needs the last paragraph.

## 4. Token
AI doesn't read words — it reads little chunks called tokens. The model
predicts one token at a time.

## 5. Tokens Per Second
The speedometer. 100 tokens/sec feels really fast; 30 starts feeling slow.
For autocomplete, speed is almost more important than intelligence.

## 6. Latency
How long until the FIRST prediction appears. A correct answer after five
seconds feels terrible. Autocomplete is exactly like that.

## 7. Prefix
Everything you've already typed. The model finishes it.

## 8. Prefix Cache
If the AI reread your entire document on every letter, it would be insanely
slow. Instead it remembers what it already read and only processes the new
characters. Huge speed improvement.

## 9. Personal Memory
NOT the language model — more like your phone's autocorrect dictionary. It
remembers your kids' names, company names, abbreviations, phrases you always
use. You always write "Thanks so much!" — eventually it suggests that.

## 10. Personal Dictionary
Even simpler: literally a list. Jamf, Tilde, Transcripted — words normal AI
doesn't know.

## 11. Phrase Memory
Remembers whole sentences you often write ("Let me know if you have any
questions.") — much cheaper than asking AI every time.

## 12. Candidate
The model doesn't generate one answer — usually several. Then another system
chooses the best one.

## 13. Candidate Ranker
Think American Idol: three sing, one wins. Which sounds most like you? Which
matches your previous writing? Which is most confident? Then it picks.

## 14. Confidence
Sometimes AI is really sure; sometimes it's guessing. Confidence measures
that. Low confidence? Probably don't show it.

## 15. Show or Stay Silent
One of the biggest ideas in Tilde. Instead of asking "what should I suggest?",
ask "SHOULD I suggest anything?" Most autocomplete talks too much. Sometimes
the best prediction is nothing.

## 16. Ghost Text
The gray text. It isn't inserted yet — it's just waiting.

## 17. Partial Acceptance
Maybe you only want the first word. Tab once: accept one word. Tab again:
another. This feels much more natural.

## 18. Reranking
After generation: "he usually writes 'Thanks so much!' — choose that one."

## 19. Fine-Tuning
Changes the actual AI brain — like sending your kid to college; they
permanently learn something new. Expensive.

## 20. LoRA
Tiny fine-tuning. Instead of changing the whole brain, clip on a small
adapter. Faster, cheaper — perfect for personalization.

## 21. Quantization
Makes models smaller, like compressing a photo — 50 MB to 8 MB, looks almost
identical. That's why everyone talks about 4-bit models.

## 22. Inference
Fancy word for "the model is thinking." Nothing more.

## 23. Distillation
A teacher explains only the important parts instead of the giant textbook.
A huge model teaches a tiny model.

## 24. Evaluation (Eval)
How you know you're improving. Instead of "does it feel better?" — measure:
how often suggestions are accepted, how often accepted text is immediately
deleted, how fast suggestions appear, how often they interrupt unnecessarily.
If those numbers improve, the product is getting better.

## 25. The four tiny employees

Forget AI for a second. Imagine four tiny employees inside your Mac:

- 👀 **The Watcher** — "he typed another letter."
- 🧠 **The Writer** — "I think he's going to write 'later today.'"
- 🤔 **The Judge** — "Hmm… I'm only 40% sure. Don't bother him."
- 📚 **The Memory** — "Actually… he always says 'Thanks so much.' Use that."

That's really all Tilde is. Not one giant AI — a handful of small,
specialized systems working together.

And the fun part: The Judge (when to stay quiet) and The Memory (learning how
you write) matter more than having the smartest language model. That's where
a small team can beat much bigger companies, because those parts are about
product design and user experience, not just raw AI horsepower.

*(Proven empirically 2026-07: the frontier model lost to the personal 2B at
predicting the owner's next word.)*
