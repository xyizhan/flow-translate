#!/usr/bin/env python3
"""Conservative, redacted privacy checks. Complements (does not replace) Gitleaks."""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXCLUDED = {".git", ".build", ".swiftpm", "dist", "verification", "__pycache__"}
RULES = {
    "private-home-path": rb"/(?:Users|home)/[A-Za-z0-9._-]+/",
    "API-token": rb"\bsk-[A-Za-z0-9_-]{20,}\b",
    "GitHub-token": rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b",
    "AWS-access-key": rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
    "private-key": rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----",
    "personal-email": rb"\b[A-Za-z0-9._%+-]+@(?:qq\.com|gmail\.com|icloud\.com|outlook\.com|hotmail\.com|163\.com|126\.com)\b",
}
FORBIDDEN_NAMES = {".DS_Store", ".env", "history.json", "vocabulary.json", "preferences.plist"}
FORBIDDEN_SUFFIXES = {".p12", ".p8", ".keychain", ".keychain-db"}


def scan(root: Path, artifact: bool) -> int:
    failures = []
    count = 0
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if not artifact and any(part in EXCLUDED for part in relative.parts):
            continue
        if path.is_symlink():
            failures.append((relative, "unexpected-symlink"))
            continue
        if not path.is_file():
            continue
        count += 1
        if path.name in FORBIDDEN_NAMES or path.suffix in FORBIDDEN_SUFFIXES:
            failures.append((relative, "private-file"))
        data = path.read_bytes()
        for rule, pattern in RULES.items():
            if re.search(pattern, data, re.IGNORECASE if rule == "personal-email" else 0):
                failures.append((relative, rule))
    for relative, rule in failures:
        print(f"FAIL: {relative} [{rule}] (matched content redacted)")
    print(f"Privacy scan: {count} files, {len(failures)} findings; {'FAIL' if failures else 'PASS'}")
    return bool(failures)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, help="Scan a complete unpacked .app, including binary bytes")
    args = parser.parse_args()
    target = args.artifact or ROOT
    if not target.is_dir():
        parser.error("Scan target must be a directory")
    raise SystemExit(scan(target, args.artifact is not None))
