#!/usr/bin/env python3
"""Documentation inventory and staleness report.

Reads the source-area -> expected-doc mapping from .claude/state/doc-map.json,
which configure.sh writes from the confirmed profile. Extend it as the project
grows.

usage: docs_audit.py [ROOT] [OUT_DIR]
writes: OUT_DIR/docs_audit.json
"""
import json
import subprocess
import sys
from pathlib import Path


def git_epoch(root: Path, rel: str) -> int:
    """Last commit time for a path, as a unix epoch. 0 when unknown."""
    try:
        r = subprocess.run(
            ['git', '-C', str(root), 'log', '-1', '--format=%ct', '--', rel],
            capture_output=True, text=True, timeout=30)
        return int(r.stdout.strip())
    except (ValueError, Exception):
        return 0


def load_doc_map(root: Path) -> dict:
    p = root / '.claude' / 'state' / 'doc-map.json'
    if p.exists():
        try:
            return json.loads(p.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    out = Path(sys.argv[2] if len(sys.argv) > 2 else 'docs/reports/latest')
    out.mkdir(parents=True, exist_ok=True)

    doc_map = load_doc_map(root)
    docs_root = root / 'docs'
    docs = sorted(str(p.relative_to(root)) for p in docs_root.rglob('*.md')) \
        if docs_root.exists() else []

    stale, missing = [], []
    for area, doc in doc_map.items():
        if not (root / area).exists():
            continue
        if not (root / doc).exists():
            missing.append({'area': area, 'expected_doc': doc})
            continue
        code_t, doc_t = git_epoch(root, area), git_epoch(root, doc)
        if code_t > doc_t:
            stale.append({'area': area, 'doc': doc,
                          'days_behind': round((code_t - doc_t) / 86400, 1)})

    spec_root = root / 'docs' / 'specs'
    specs = [s for s in sorted(spec_root.glob('*')) if s.is_dir()] \
        if spec_root.exists() else []

    # A spec directory with no verification.md is a feature that shipped
    # without passing VERIFY. This list is the fastest signal of process drift.
    unverified = [s.name for s in specs if not (s / 'verification.md').exists()]

    adr_root = root / 'docs' / 'adr'
    adrs = sorted(p.name for p in adr_root.glob('*.md')
                  if p.name != 'TEMPLATE.md') if adr_root.exists() else []

    tracked = max(len(doc_map), 1)
    report = {
        'doc_count': len(docs),
        'adr_count': len(adrs),
        'adrs': adrs,
        'spec_count': len(specs),
        'specs_without_verification': unverified,
        'missing_docs': missing,
        'stale_docs': sorted(stale, key=lambda d: -d['days_behind']),
        'coverage_pct': round(100 * (tracked - len(missing) - len(stale)) / tracked, 1),
        'all_docs': docs,
    }
    (out / 'docs_audit.json').write_text(json.dumps(report, indent=2))
    print(f"wrote {out / 'docs_audit.json'}: coverage {report['coverage_pct']}% · "
          f"{len(stale)} stale · {len(missing)} missing · "
          f"{len(unverified)} specs unverified")


if __name__ == '__main__':
    main()
