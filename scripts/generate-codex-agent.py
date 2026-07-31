#!/usr/bin/env python3
"""Generate a Codex TOML role adapter from a canonical Claude Markdown role."""

from __future__ import annotations

import json
import pathlib
import sys


def parse_role(path: pathlib.Path) -> tuple[str, str, str]:
    text = path.read_text()
    if not text.startswith("---\n"):
        raise ValueError(f"{path} has no YAML frontmatter")

    _, frontmatter, body = text.split("---\n", 2)
    values: dict[str, str] = {}
    for line in frontmatter.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()

    name = values.get("name", "")
    description = values.get("description", "")
    if not name or not description:
        raise ValueError(f"{path} must define name and description")
    return name, description, body.lstrip()


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: generate-codex-agent.py <source.md> <destination.toml>", file=sys.stderr)
        return 2

    source = pathlib.Path(sys.argv[1])
    destination = pathlib.Path(sys.argv[2])
    name, description, instructions = parse_role(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        f"name = {json.dumps(name)}\n"
        f"description = {json.dumps(description)}\n"
        f"developer_instructions = {json.dumps(instructions)}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
