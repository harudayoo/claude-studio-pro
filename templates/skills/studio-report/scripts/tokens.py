#!/usr/bin/env python3
"""Token consumption report for a period.

Two sources, in order of durability:

1. An OTLP collector. If you have Prometheus, the queries this script prints are
   the report — run them there. Metrics survive Claude Code releases.
2. Local session transcripts under ~/.claude/projects/. This is the fallback.
   The transcript format is INTERNAL to Claude Code and changes between
   releases, so treat these numbers as indicative, and say so in the report.

usage: tokens.py [YYYY-MM] [OUT_DIR]
writes: OUT_DIR/tokens.json
"""
import json
import os
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

PROM_QUERIES = {
    'monthly_tokens_by_model':
        'sum by (model) (increase(claude_code_token_usage_tokens_total[30d]))',
    'attribution_by_agent':
        'sum by (agent_name) (increase(claude_code_token_usage_tokens_total[30d]))',
    'main_vs_subagent':
        'sum by (query_source) (increase(claude_code_token_usage_tokens_total[30d]))',
    'cache_efficiency':
        'sum(increase(claude_code_token_usage_tokens_total{type="cacheRead"}[30d]))'
        ' / sum(increase(claude_code_token_usage_tokens_total{type="input"}[30d]))',
    'monthly_cost':
        'sum(increase(claude_code_cost_usage_USD_total[30d]))',
    'tokens_per_accepted_change':
        'sum(increase(claude_code_token_usage_tokens_total[30d]))'
        ' / sum(increase(claude_code_pull_request_count_total[30d]))',
}

USAGE_KEYS = ('input_tokens', 'output_tokens',
              'cache_read_input_tokens', 'cache_creation_input_tokens')


def period_bounds(period: str):
    """'YYYY-MM' -> (start, end) as aware datetimes."""
    year, month = (int(x) for x in period.split('-'))
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    end = datetime(year + (month // 12), (month % 12) + 1, 1, tzinfo=timezone.utc)
    return start, end


def iter_transcript_events(start, end):
    """Yield (model, usage_dict) from local session transcripts in the period.

    Best-effort by design: unknown record shapes are skipped rather than
    guessed at.
    """
    base = Path(os.path.expanduser('~/.claude/projects'))
    if not base.exists():
        return
    for path in base.rglob('*.jsonl'):
        try:
            mtime = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
        except OSError:
            continue
        if not (start <= mtime < end):
            continue
        try:
            with path.open('r', errors='ignore') as fh:
                for line in fh:
                    line = line.strip()
                    if not line or '"usage"' not in line:
                        continue
                    try:
                        rec = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    msg = rec.get('message') if isinstance(rec.get('message'), dict) else rec
                    usage = msg.get('usage') if isinstance(msg, dict) else None
                    if not isinstance(usage, dict):
                        continue
                    yield (msg.get('model') or 'unknown'), usage
        except OSError:
            continue


def merged_changes(period: str) -> int:
    """Merge commits in the period — the denominator for tokens per change."""
    start, end = period_bounds(period)
    try:
        out = subprocess.run(
            ['git', 'log', '--merges', '--oneline',
             f'--since={start:%Y-%m-%d}', f'--until={end:%Y-%m-%d}'],
            capture_output=True, text=True, timeout=30).stdout
        return len([l for l in out.splitlines() if l.strip()])
    except Exception:
        return 0


def main():
    period = sys.argv[1] if len(sys.argv) > 1 and '-' in sys.argv[1] else \
        datetime.now(timezone.utc).strftime('%Y-%m')
    out = Path(sys.argv[2] if len(sys.argv) > 2 else 'docs/reports/latest')
    out.mkdir(parents=True, exist_ok=True)

    start, end = period_bounds(period)
    by_model = defaultdict(lambda: dict.fromkeys(USAGE_KEYS, 0))
    events = 0
    for model, usage in iter_transcript_events(start, end):
        events += 1
        for k in USAGE_KEYS:
            v = usage.get(k)
            if isinstance(v, int):
                by_model[model][k] += v

    total = sum(sum(v.values()) for v in by_model.values())
    cache_read = sum(v['cache_read_input_tokens'] for v in by_model.values())
    fresh_input = sum(v['input_tokens'] for v in by_model.values())
    changes = merged_changes(period)

    report = {
        'period': period,
        'source': 'local-transcripts' if events else 'none',
        'caveat': (
            'Parsed from local Claude Code session transcripts, which are an '
            'internal format that changes between releases, and are per-machine. '
            'Label these numbers as indicative, not measured. The durable route '
            'is an OTLP collector — see prometheus_queries below.'
        ),
        'events_parsed': events,
        'total_tokens': total,
        'by_model': {k: dict(v, total=sum(v.values())) for k, v in by_model.items()},
        'cache_read_ratio': round(cache_read / fresh_input, 2) if fresh_input else None,
        'merged_changes': changes,
        'tokens_per_accepted_change': round(total / changes) if changes else None,
        'prometheus_queries': PROM_QUERIES,
    }
    (out / 'tokens.json').write_text(json.dumps(report, indent=2))

    if events:
        print(f"wrote {out / 'tokens.json'}: {total:,} tokens over {events} events, "
              f"{changes} merged changes"
              + (f", TPAC {report['tokens_per_accepted_change']:,}" if changes else ""))
        print("source: local transcripts (indicative, not measured)")
    else:
        print(f"wrote {out / 'tokens.json'}: no local transcript data for {period}.")
        print("Use /usage in-session, or stand up an OTLP collector and run the "
              "queries in prometheus_queries.")


if __name__ == '__main__':
    main()
