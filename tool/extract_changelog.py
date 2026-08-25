#!/usr/bin/env python3
"""
Extracts changelog release notes for a specific version or tag from CHANGELOG.md.
Usage:
    python3 tool/extract_changelog.py [tag_or_version] [output_file]
Example:
    python3 tool/extract_changelog.py v1.1.6 RELEASE_NOTES.md
"""

import re
import sys
from pathlib import Path


def configure_utf8_output() -> None:
    """Use UTF-8 for console output, including on Windows runners."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="backslashreplace")
            except (OSError, ValueError):
                # Some embedded or already-closed streams cannot be reconfigured.
                continue


def extract_changelog(tag_or_version: str, changelog_path: str = "CHANGELOG.md") -> str:
    version = tag_or_version.lstrip("v").strip()

    file_path = Path(changelog_path)
    if not file_path.exists():
        return f"## Release {tag_or_version}\n"

    content = file_path.read_text(encoding="utf-8")

    # Try exact match for ## [1.1.6]
    pattern = rf"(##\s*\[{re.escape(version)}\][^\n]*\n(?:(?!##\s*\[).)*)"
    match = re.search(pattern, content, re.DOTALL)

    if match:
        return match.group(1).strip()

    # Fallback to the first release entry if version not matched
    fallback_match = re.search(r"(##\s*\[[^\]]+\][^\n]*\n(?:(?!##\s*\[).)*)", content, re.DOTALL)
    if fallback_match:
        return fallback_match.group(1).strip()

    return f"## Release {tag_or_version}\n"


def main():
    configure_utf8_output()

    tag_or_version = sys.argv[1] if len(sys.argv) > 1 else "latest"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "RELEASE_NOTES.md"

    notes = extract_changelog(tag_or_version)
    Path(output_file).write_text(notes + "\n", encoding="utf-8")
    print(f"Extracted changelog for '{tag_or_version}' to '{output_file}'.")


if __name__ == "__main__":
    main()
