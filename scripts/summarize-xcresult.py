#!/usr/bin/env python3
"""Print compact per-target counts from an Xcode result bundle."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def xcresult_json(result: Path, section: str) -> dict:
    completed = subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "get",
            "test-results",
            section,
            "--path",
            str(result),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(completed.stdout)


def test_cases(node: dict):
    if node.get("nodeType") == "Test Case":
        yield node
    for child in node.get("children", []):
        yield from test_cases(child)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: summarize-xcresult.py RESULT.xcresult", file=sys.stderr)
        return 2

    result = Path(sys.argv[1])
    summary = xcresult_json(result, "summary")
    tests = xcresult_json(result, "tests")

    rows: list[tuple[str, int, int, int, int, float]] = []
    for plan in tests.get("testNodes", []):
        for bundle in plan.get("children", []):
            cases = list(test_cases(bundle))
            passed = sum(case.get("result") == "Passed" for case in cases)
            failed = sum(case.get("result") == "Failed" for case in cases)
            skipped = sum(case.get("result") == "Skipped" for case in cases)
            duration = sum(float(case.get("durationInSeconds", 0)) for case in cases)
            rows.append((bundle.get("name", "unknown"), len(cases), passed, failed, skipped, duration))

    print("Target                                     Runs   Pass   Fail   Skip   Σ test time")
    for name, count, passed, failed, skipped, duration in sorted(rows):
        print(f"{name:<42} {count:>5} {passed:>6} {failed:>6} {skipped:>6} {duration:>10.2f}s")
    print(
        "Logical total: "
        f"{summary.get('totalTestCount', 0)}; result: {summary.get('result', 'unknown')}. "
        "Σ test time is cumulative work and may exceed wall time when tests run in parallel."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
