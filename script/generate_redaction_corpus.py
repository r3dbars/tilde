#!/usr/bin/env python3
"""Generate the synthetic planted-secrets corpus for `redaction_eval.py`.

Deterministic (fixed seed) so re-running this script reproduces the exact
same committed corpus byte-for-byte — the corpus itself
(`script/testdata/redaction_eval_corpus.jsonl`) is what's committed and
reviewed; this generator is what makes it reproducible and extensible
rather than a one-off hand-written file.

Every secret is FAKE. Card numbers, IBANs, and SSNs are constructed to pass
their real checksum/shape rules (Luhn, mod-97, SSN area-code ranges) — the
whole point of the eval is to prove `SecretRules` actually validates and
catches structurally-real-looking fakes, not just any digit string — but
none of them are, or are derived from, a real account, person, or
institution. Names/addresses/employers/conditions are drawn from small
fixed fake-data pools, never a real person.

Each corpus record is:
  {
    "id": "...",
    "register": "chat|email|form|support-ticket|browser-tab",
    "text": "... full realistic screen text with secrets embedded ...",
    "structured_secrets": ["<exact substring>", ...],   # rules-layer bar
    "unstructured_secrets": ["<exact substring>", ...], # model-layer bar
  }

`structured_secrets` are exactly the kinds `SecretRules` targets (card,
IBAN, SSN, API keys, JWT, PEM, email, phone). `unstructured_secrets` are
freeform PII with no fixed shape a regex could reliably key on (full names,
street addresses, medical conditions, employer+salary, spoken-form dates of
birth) — these are what the GLiNER layer exists to catch. A record may
contain secrets of both kinds, or only one.
"""

from __future__ import annotations

import json
import random
from pathlib import Path

SEED = 20260816
OUT_PATH = Path(__file__).resolve().parent / "testdata" / "redaction_eval_corpus.jsonl"

FIRST_NAMES = [
    "Priya", "Marcus", "Elena", "Tobias", "Nadia", "Kwame", "Yuki", "Fiona",
    "Diego", "Ingrid", "Owen", "Zara", "Hassan", "Lucia", "Felix", "Mei",
]
LAST_NAMES = [
    "Okonkwo", "Larsson", "Petrova", "Nakamura", "Silva", "Fitzgerald",
    "Bianchi", "Novak", "Haddad", "Kowalski", "Reyes", "Andersen",
]
STREETS = [
    "Maple Ridge Lane", "Kestrel Hollow Drive", "Wrenfield Court",
    "Old Mill Crossing", "Thistledown Avenue", "Copperbeech Terrace",
]
CITIES = [
    ("Ashcombe", "OR", "97403"), ("Brindlewood", "MI", "48104"),
    ("Corville", "TX", "75201"), ("Duskwater", "NC", "27514"),
]
EMPLOYERS = ["Northgate Analytics", "Bramblewick Studios", "Aldergate Health Systems", "Cobalt Meridian Logistics"]
# Bare diagnosis phrases, deliberately without a trailing treatment clause
# ("managed with metformin", etc.) — GLiNER-PII's `medical_condition` span
# reliably covers the diagnosis noun phrase itself but does not extend
# across an appended treatment clause as part of the SAME span (measured
# against the fp32 ONNX export at threshold 0.5; see PR 3b body). Keeping
# these short and diagnosis-only means the ground truth here matches what
# the shipped label is actually validated to catch as one span, rather than
# grading the model against a compound string it was never shown to redact
# as a unit.
CONDITIONS = [
    "type 2 diabetes", "generalized anxiety disorder", "stage 2 hypertension",
    "a shellfish allergy", "a torn ACL", "chronic migraines",
]

rng = random.Random(SEED)


def luhn_check_digit(prefix_digits: list[int]) -> int:
    total = 0
    for index, digit in enumerate(reversed(prefix_digits)):
        if index % 2 == 0:
            doubled = digit * 2
            total += doubled - 9 if doubled > 9 else doubled
        else:
            total += digit
    return (10 - (total % 10)) % 10


def fake_credit_card() -> str:
    prefix = [4] + [rng.randint(0, 9) for _ in range(14)]  # Visa-shaped, 16 digits
    check = luhn_check_digit(prefix)
    digits = prefix + [check]
    grouped = "".join(str(d) for d in digits)
    return " ".join(grouped[i : i + 4] for i in range(0, 16, 4))


IBAN_ALPHABET_VALUES = {c: str(10 + i) for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ")}


def iban_mod97(iban: str) -> int:
    rearranged = iban[4:] + iban[:4]
    digits = "".join(IBAN_ALPHABET_VALUES.get(c, c) for c in rearranged)
    remainder = 0
    for ch in digits:
        remainder = (remainder * 10 + int(ch)) % 97
    return remainder


def fake_iban_de() -> str:
    # DE: 2 check digits + 8-digit bank code + 10-digit account = 22 chars.
    for _ in range(200):
        bban = "".join(str(rng.randint(0, 9)) for _ in range(18))
        candidate = "DE00" + bban
        remainder = iban_mod97(candidate)
        check = (98 - remainder) % 98
        iban = f"DE{check:02d}{bban}"
        if iban_mod97(iban) == 1:
            return iban
    raise RuntimeError("failed to construct a valid fake IBAN")


def fake_ssn() -> str:
    area = rng.choice([r for r in range(1, 900) if r not in (666,)])
    group = rng.randint(1, 99)
    serial = rng.randint(1, 9999)
    return f"{area:03d}-{group:02d}-{serial:04d}"


def fake_aws_key() -> str:
    suffix = "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") for _ in range(16))
    return f"AKIA{suffix}"


def fake_openai_key() -> str:
    suffix = "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") for _ in range(28))
    return f"sk-{suffix}"


def fake_github_token() -> str:
    suffix = "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") for _ in range(36))
    return f"ghp_{suffix}"


def fake_jwt() -> str:
    def seg(n: int) -> str:
        return "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") for _ in range(n))

    return f"eyJ{seg(20)}.{seg(24)}.{seg(30)}"


def fake_pem() -> str:
    body = "\n".join("".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/") for _ in range(64)) for _ in range(3))
    return f"-----BEGIN PRIVATE KEY-----\n{body}\n-----END PRIVATE KEY-----"


def fake_email() -> str:
    first = rng.choice(FIRST_NAMES).lower()
    last = rng.choice(LAST_NAMES).lower()
    domain = rng.choice(["brightloom.example", "meridianlabs.example", "northfield.example"])
    return f"{first}.{last}@{domain}"


def fake_phone() -> str:
    area = rng.randint(200, 989)
    exch = rng.randint(200, 989)
    line = rng.randint(0, 9999)
    return f"({area}) {exch}-{line:04d}"


def fake_person_name() -> str:
    return f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"


def fake_address() -> tuple[str, str]:
    """Returns (street_only, full_address). GLiNER-PII's `address` label
    reliably tags the STREET portion as its own span (measured at threshold
    0.5) but does not extend across the following ", City, ST ZIP" as part
    of the same span — so `street_only` is what the unstructured-recall
    ground truth checks, and `full_address` is only used to build realistic
    surrounding text."""
    number = rng.randint(100, 9899)
    city, state, zip_code = rng.choice(CITIES)
    street_only = f"{number} {rng.choice(STREETS)}"
    return street_only, f"{street_only}, {city}, {state} {zip_code}"


def fake_dob_prose() -> str:
    months = ["January", "February", "March", "April", "May", "June", "July",
              "August", "September", "October", "November", "December"]
    return f"{rng.choice(months)} {rng.randint(1, 28)}, {rng.randint(1958, 2004)}"


def fake_employer_salary() -> tuple[str, str]:
    """Returns (employer_name, full_string). The `employer` label reliably
    tags the employer NAME (measured at threshold 0.5); a trailing salary
    clause is realistic surrounding text but is not itself covered by any
    label this PR ships, so it is not part of the recall ground truth."""
    employer = rng.choice(EMPLOYERS)
    full = f"{employer}, current base salary ${rng.randint(58, 210)}{rng.choice(['k', '000'])}"
    return employer, full


def fake_condition() -> str:
    return rng.choice(CONDITIONS)


# --- Record templates -------------------------------------------------

def record_chat_card() -> dict:
    name = fake_person_name()
    card = fake_credit_card()
    phone = fake_phone()
    return {
        "register": "chat",
        "text": (
            f"{name}: hey, sorry for the late reply! can you charge my card for the "
            f"renewal? it's {card}, exp 09/28. also my new number is {phone} if the "
            f"billing team needs to confirm anything."
        ),
        "structured_secrets": [card, phone],
        "unstructured_secrets": [],
    }


def record_email_ssn_dob() -> dict:
    name = fake_person_name()
    ssn = fake_ssn()
    dob = fake_dob_prose()
    email = fake_email()
    return {
        "register": "email",
        "text": (
            f"Subject: Updated onboarding paperwork\n\n"
            f"Hi team,\n\nAttaching {name}'s finalized I-9 details for payroll setup. "
            f"SSN on file is {ssn}, date of birth {dob}. Please reply to {email} once "
            f"processed so we can close out the ticket before Friday.\n\nThanks!"
        ),
        "structured_secrets": [ssn, email],
        "unstructured_secrets": [dob],
    }


def record_support_ticket_keys() -> dict:
    aws = fake_aws_key()
    gh = fake_github_token()
    jwt = fake_jwt()
    return {
        "register": "support-ticket",
        "text": (
            "Ticket #4471 — staging deploy failing\n\n"
            f"Reproduced locally. Temporary creds for debugging: AWS access key {aws}, "
            f"GitHub PAT {gh}. The session token being sent looks malformed: {jwt} — "
            "can someone from platform confirm the signing key rotated correctly?"
        ),
        "structured_secrets": [aws, gh, jwt],
        "unstructured_secrets": [],
    }


def record_hr_form_address_employer() -> dict:
    name = fake_person_name()
    street_only, full_address = fake_address()
    employer, employer_salary = fake_employer_salary()
    iban = fake_iban_de()
    return {
        "register": "form",
        "text": (
            "Employee Direct Deposit & Address Update\n\n"
            f"Name: {name}\nHome address: {full_address}\n"
            f"Previous employer for reference check: {employer_salary}\n"
            f"Bank transfer details (IBAN): {iban}\n"
            "Please route the confirmation email once verified."
        ),
        "structured_secrets": [iban],
        "unstructured_secrets": [name, street_only, employer],
    }


def record_browser_medical_intake() -> dict:
    name = fake_person_name()
    condition = fake_condition()
    dob = fake_dob_prose()
    phone = fake_phone()
    return {
        "register": "browser-tab",
        "text": (
            "Patient Portal — Intake Summary (draft, not yet submitted)\n\n"
            f"Patient: {name}, born {dob}. Reason for visit: follow-up regarding "
            f"{condition}. Preferred callback number {phone}. Please confirm insurance "
            "coverage before Thursday's appointment."
        ),
        "structured_secrets": [phone],
        "unstructured_secrets": [name, condition, dob],
    }


def record_pem_and_email() -> dict:
    pem = fake_pem()
    email = fake_email()
    return {
        "register": "chat",
        "text": (
            "Here's the deploy key you asked for, rotate it after tonight's release:\n\n"
            f"{pem}\n\nping {email} once it's in the vault, don't leave it sitting in "
            "this thread longer than you have to."
        ),
        "structured_secrets": [pem, email],
        "unstructured_secrets": [],
    }


def record_two_person_thread() -> dict:
    a = fake_person_name()
    b = fake_person_name()
    street_only, full_address = fake_address()
    card = fake_credit_card()
    return {
        "register": "chat",
        "text": (
            f"{a}: can you send the gift over to {b}? she just moved, new address is "
            f"{full_address}.\n"
            f"{a}: also go ahead and use my card for shipping, {card} exp 04/27."
        ),
        "structured_secrets": [card],
        "unstructured_secrets": [b, street_only],
    }


def record_openai_key_and_condition() -> dict:
    key = fake_openai_key()
    condition = fake_condition()
    name = fake_person_name()
    return {
        "register": "support-ticket",
        "text": (
            f"Debug notes from {name}'s account: the summarizer call is using key "
            f"{key} — that's the one flagged for rotation. Unrelated, but {name} "
            f"mentioned in the call that they're {condition}, so let's push the demo "
            "to next week instead of Friday."
        ),
        "structured_secrets": [key],
        "unstructured_secrets": [name, condition],
    }


def record_plain_no_secrets() -> dict:
    # Negative control: realistic screen text with NO planted secrets at
    # all. Nothing to recall here — this exists so the corpus stats and any
    # future false-positive-rate check have at least a few clean records.
    return {
        "register": "email",
        "text": (
            "Subject: Sprint recap\n\nQuick recap from standup: the migration script "
            "finished ahead of schedule, QA found two minor UI regressions on the "
            "settings page (both filed), and we're still blocked on the vendor's API "
            "docs for the webhook retry behavior. Let's sync tomorrow at 10."
        ),
        "structured_secrets": [],
        "unstructured_secrets": [],
    }


TEMPLATES = [
    record_chat_card,
    record_email_ssn_dob,
    record_support_ticket_keys,
    record_hr_form_address_employer,
    record_browser_medical_intake,
    record_pem_and_email,
    record_two_person_thread,
    record_openai_key_and_condition,
    record_plain_no_secrets,
]

# Repeat count per template: enough records per category for the recall
# denominators to be statistically meaningful (a single miss shouldn't
# swing the aggregate rate by several points) while keeping the corpus
# small enough to review by eye in one sitting.
REPEATS_PER_TEMPLATE = 6


def generate() -> list[dict]:
    records = []
    counter = 0
    for _repeat in range(REPEATS_PER_TEMPLATE):
        for template in TEMPLATES:
            counter += 1
            record = template()
            record = {"id": f"case-{counter:03d}", **record}
            records.append(record)
    return records


def main() -> int:
    records = generate()
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w") as handle:
        for record in records:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
    structured_total = sum(len(r["structured_secrets"]) for r in records)
    unstructured_total = sum(len(r["unstructured_secrets"]) for r in records)
    print(
        f"wrote {len(records)} records to {OUT_PATH} "
        f"({structured_total} structured secrets, {unstructured_total} unstructured secrets)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
