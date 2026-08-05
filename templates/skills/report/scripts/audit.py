#!/usr/bin/env python3
"""Codebase + documentation audit. Runs in a script so it costs zero tokens."""
import json
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

IGNORE = {'.git', 'node_modules', 'vendor', 'dist', 'build', '__pycache__',
          '.venv', 'venv', '.next', 'target', 'storage'}
CODE = {'.php', '.js', '.ts', '.tsx', '.jsx', '.vue', '.svelte', '.py',
        '.go', '.rs', '.rb', '.java', '.kt', '.css', '.scss'}

# Adapt this in setup: source area -> the doc that is supposed to describe it.
DOC_MAP = json.loads(Path('.claude/state/doc-map.json').read_text()) \
    if Path('.claude/state/doc-map.json').exists() else {}


def git_epoch(root, rel):
    r = subprocess.run(['git', '-C', str(root), 'log', '-1', '--format=%ct', '--', rel],
                       capture_output=True, text=True, check=False)
    try:
        return int(r.stdout.strip())
    except ValueError:
        return 0


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    out = Path(sys.argv[2] if len(sys.argv) > 2 else 'docs/reports/latest')
    out.mkdir(parents=True, exist_ok=True)

    files, by_dir = [], defaultdict(lambda: {'files': 0, 'lines': 0})
    for p in root.rglob('*'):
        if not p.is_file() or p.suffix.lower() not in CODE:
            continue
        if any(part in IGNORE for part in p.parts):
            continue
        try:
            lines = sum(1 for _ in p.open('r', errors='ignore'))
        except OSError:
            continue
        rel = p.relative_to(root)
        top = rel.parts[0] if len(rel.parts) > 1 else '(root)'
        files.append({'path': str(rel), 'lines': lines})
        by_dir[top]['files'] += 1
        by_dir[top]['lines'] += lines

    churn_out = subprocess.run(
        ['git', '-C', str(root), 'log', '--since=1 month ago',
         '--name-only', '--pretty=format:'],
        capture_output=True, text=True, check=False).stdout
    churn = dict(Counter(l for l in churn_out.splitlines() if l.strip()).most_common(20))

    largest = {f['path'] for f in sorted(files, key=lambda f: -f['lines'])[:25]}
    hotspots = [p for p in churn if p in largest]

    stale, missing = [], []
    for area, doc in DOC_MAP.items():
        if not (root / area).exists():
            continue
        if not (root / doc).exists():
            missing.append({'area': area, 'expected_doc': doc})
            continue
        ct, dt = git_epoch(root, area), git_epoch(root, doc)
        if ct > dt:
            stale.append({'doc': doc, 'area': area,
                          'days_behind': round((ct - dt) / 86400, 1)})

    spec_root = root / 'docs' / 'specs'
    specs = [s for s in spec_root.glob('*') if s.is_dir()] if spec_root.exists() else []

    report = {
        'totals': {'files': len(files), 'lines': sum(f['lines'] for f in files)},
        'by_module': dict(sorted(by_dir.items(), key=lambda x: -x[1]['lines'])),
        'largest': sorted(files, key=lambda f: -f['lines'])[:20],
        'most_churned': churn,
        'hotspots_large_and_churned': hotspots,
        'stale_docs': sorted(stale, key=lambda d: -d['days_behind']),
        'missing_docs': missing,
        'spec_count': len(specs),
        'specs_without_verification': [s.name for s in specs
                                       if not (s / 'verification.md').exists()],
    }
    (out / 'audit.json').write_text(json.dumps(report, indent=2))
    print(f"{report['totals']['files']} files, {report['totals']['lines']:,} lines | "
          f"{len(hotspots)} hotspots | {len(stale)} stale docs | "
          f"{len(report['specs_without_verification'])} unverified specs")
    print(f"wrote {out / 'audit.json'}")


if __name__ == '__main__':
    main()
