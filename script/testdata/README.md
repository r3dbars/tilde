# Synthetic test data

Everything in this directory is generated, not collected. The redaction
evaluation corpus contains strings shaped like real secrets — AWS access keys,
GitHub tokens, session tokens, private-key blocks, email addresses — precisely
so the redaction rules can be scored against them. None is a working
credential; the addresses use reserved example domains; the corpus is written
by `script/generate_redaction_corpus.py` from a fixed seed. GitHub secret
scanning is told to skip this directory in `.github/secret_scanning.yml`.
