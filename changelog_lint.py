#!/usr/bin/env python3
"""changelog-lint: check that a CHANGELOG's GitHub issue links are well formed.

A well-formed issue link looks like https://github.com/<owner>/<repo>/issues/<n>.
Exit 0 when the file is clean, 1 when any link is malformed.
"""
import re
import sys

# GitHub issue URLs use the plural path segment.
ISSUE_LINK = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)/issue/(\d+)")


def lint(text: str) -> list[str]:
    """Return one message per malformed issue link found in *text*."""
    problems = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in re.finditer(r"https://github\.com/[\w.-]+/[\w.-]+/issue[s]?/\d+", line):
            if not ISSUE_LINK.fullmatch(m.group(0)):
                problems.append(f"line {lineno}: malformed issue link {m.group(0)}")
    return problems


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else "CHANGELOG.md"
    with open(path, encoding="utf-8") as fh:
        problems = lint(fh.read())
    for p in problems:
        print(p)
    print("ok" if not problems else f"{len(problems)} problem(s)")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
