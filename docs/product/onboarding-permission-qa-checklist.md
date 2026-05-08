# Onboarding Permission QA Checklist

Use this before a private beta build. This is manual proof, not a code claim.

## Clean Install

- [ ] Install the app with Accessibility off.
- [ ] Confirm the app opens its own Settings/onboarding surface before any macOS Accessibility prompt appears.
- [ ] Confirm the first screen explains the value and local-first behavior in plain language.
- [ ] Click `Allow Accessibility`.
- [ ] Confirm the app explains why System Settings is opening.
- [ ] Grant Accessibility, return to the app, and confirm the status updates without restart.

## First Success

- [ ] Confirm suggestion-capable apps start off on a fresh install.
- [ ] Enable TextEdit only.
- [ ] Type disposable text in TextEdit.
- [ ] Confirm a suggestion appears near the cursor.
- [ ] Press `Tab` and confirm only the next word inserts.
- [ ] Press `Esc` and confirm the suggestion dismisses without changing text.

## Permission Recovery

- [ ] Deny or remove Accessibility.
- [ ] Confirm the app stays calm and says suggestions need Accessibility.
- [ ] Confirm `Open Privacy Settings` returns the user to the right Settings area.
- [ ] Confirm Screen Recording is not requested during normal autocomplete setup.

## Diagnostics

- [ ] Turn on screenshot proof only from an explicit diagnostics/proof action.
- [ ] Confirm Settings says Screen Recording is only for local placement screenshots.
- [ ] Confirm screenshot proof can be turned off.
- [ ] Confirm `Delete Local Logs` removes local traces and screenshot files.

## Model Setup

- [ ] Start without the local model installed.
- [ ] Confirm Settings says the model download uses Hugging Face once and suggestions run locally after install.
- [ ] Start the install and confirm progress is visible.
- [ ] Confirm low disk space is caught before a network download starts, or record why the scenario could not be safely reproduced.
- [ ] Cancel the install and confirm the app returns to a recoverable state.
- [ ] Repair an incomplete model folder and confirm suggestions stay off until validation passes.

## Release Rule

Do not invite private beta testers until this checklist passes on a clean macOS user account.
