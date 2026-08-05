#!/usr/bin/env python3
"""Codebase structure report. Runs in a script so it costs zero tokens.

usage: structure.py [ROOT] [OUT_DIR]
writes: OUT_DIR/structure.json
"""
import json
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

IGNORE = {'.git', 'node_modules', 'vendor', 'dist', 'build', '__pycache__',
          '.venv', 'venv', 'storage', 'public/build', '.next', 'target'}
CODE = {'.php', '.js', '.ts', '.tsx', '.jsx', '.vue', '.svelte', '.py', '.go',
        '.rs', '.rb', '.java', '.kt', '.cs', '.css', '.scss', '.blade.php'}


def walk(root: Path):
    files, by_ext, by_dir = [], Counter(), defaultdict(lambda: {'files': 0, 'lines': 0})
    for p in root.rglob('*'):
        if any(part in IGNORE for part in p.parts) or not p.is_file():
            continue
        ext = p.suffix.lower()
        if ext not in CODE:
            continue
        try:
            lines = sum(1 for _ in p.open('r', errors='ignore'))
        except OSError:
            continue
        rel = p.relative_to(root)
        top = rel.parts[0] if len(rel.parts) > 1 else '(root)'
        files.append({'path': str(rel), 'lines': lines, 'ext': ext})
        by_ext[ext] += lines
        by_dir[top]['files'] += 1
        by_dir[top]['lines'] += lines
    return files, by_ext, by_dir


def churn(root: Path, since='1 month ago'):
    try:
        out = subprocess.run(
            ['git', '-C', str(root), 'log', f'--since={since}',
             '--name-only', '--pretty=format:'],
            capture_output=True, text=True, timeout=60, check=False).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    return dict(Counter(l for l in out.splitlines() if l.strip()).most_common(30))


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    out = Path(sys.argv[2] if len(sys.argv) > 2 else 'docs/reports/latest')
    out.mkdir(parents=True, exist_ok=True)

    files, by_ext, by_dir = walk(root)
    churned = churn(root)

    # The interesting output is not the line count. It is the intersection of
    # largest and most-churned: that is where defects and token spend both
    # concentrate.
    largest = sorted(files, key=lambda f: -f['lines'])[:25]
    largest_paths = {f['path'] for f in largest}
    hotspots = [p for p in churned if p in largest_paths]

    report = {
        'generated': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'totals': {'files': len(files), 'lines': sum(f['lines'] for f in files)},
        'by_extension': dict(by_ext.most_common()),
        'by_module': {k: v for k, v in sorted(by_dir.items(), key=lambda x: -x[1]['lines'])},
        'largest_files': largest,
        'most_churned': churned,
        'hotspots_large_and_churned': hotspots,
    }
    (out / 'structure.json').write_text(json.dumps(report, indent=2))
    print(f"wrote {out / 'structure.json'}: {report['totals']['files']} files, "
          f"{report['totals']['lines']:,} lines, {len(hotspots)} hotspots")


if __name__ == '__main__':
    main()
