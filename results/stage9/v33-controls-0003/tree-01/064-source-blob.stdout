#!/usr/bin/env python3
"""Export recorded usage and a content-hash index without private transcript text."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest

THREAD = '01a178b4-689b-7452-98ac-42280e315b9b'
START_TURN = '01a17a5e-1639-7522-8c26-56ed2a435246'
CATEGORIES = ('input_tokens', 'cached_input_tokens', 'cache_write_input_tokens',
              'output_tokens', 'reasoning_output_tokens', 'total_tokens')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', type=Path, required=True)
    args = parser.parse_args()
    data = args.session.read_bytes()
    lines = data.splitlines(keepends=True)
    if lines and not lines[-1].endswith(b'\n'):
        lines.pop()
    rows = [json.loads(line) for line in lines]
    start = next(i for i, row in enumerate(rows)
                 if row.get('type') == 'turn_context' and row['payload'].get('turn_id') == START_TURN)
    usages = [(i, row['payload']) for i, row in enumerate(rows) if row.get('type') == 'token_usage_record']
    first = next(i for i, (_, payload) in enumerate(usages) if payload['turn_id'] == START_TURN)
    selected = usages[first:]
    assert selected and all(p['thread_id'] == THREAD for _, p in selected)
    assert len({p['response_id'] for _, p in selected}) == len(selected)
    assert all(set(p['usage']) == set(CATEGORIES) for _, p in selected)
    assert all(p['usage']['total_tokens'] == p['usage']['input_tokens'] + p['usage']['output_tokens']
               for _, p in selected)
    assert all(p['usage']['cached_input_tokens'] <= p['usage']['input_tokens'] and
               p['usage']['reasoning_output_tokens'] <= p['usage']['output_tokens'] for _, p in selected)
    totals = {key: sum(p['usage'][key] for _, p in selected) for key in CATEGORIES}
    prior = usages[first - 1][1]['thread_token_usage']
    ending = selected[-1][1]['thread_token_usage']
    assert totals == {key: ending[key] - prior[key] for key in CATEGORIES}
    last_index = selected[-1][0]
    prefix = b''.join(lines[:last_index + 1])
    transcript, human, automatic = [], [], []
    for i in range(start, last_index + 1):
        row = rows[i]
        if row.get('type') not in ('response_item', 'turn_context', 'compacted'):
            continue
        payload = row['payload']
        transcript.append({'source_line': i + 1, 'ordinal': row.get('ordinal'),
                           'record_type': row['type'], 'item_type': payload.get('type'),
                           'role': payload.get('role'), 'content_sha256': digest(lines[i]),
                           'record_bytes': len(lines[i])})
        if row['type'] == 'response_item' and payload.get('role') == 'user':
            text = '\n'.join(part.get('text', '') for part in payload.get('content', [])
                             if isinstance(part, dict))
            if '<codex_internal_context source="goal">' in text:
                automatic.append({'source_line': i + 1, 'content_sha256': digest(lines[i])})
            else:
                # Record intervention text only when it is one of the observed
                # short project messages. Other content remains hash-indexed.
                allowed = ('go ahead', 'how is it going so far', 'how is it going')
                human.append({'source_line': i + 1, 'content_sha256': digest(lines[i]),
                              'message': text if text.strip() in allowed else None,
                              'kind': 'intent_approval' if text.strip() == 'go ahead' else 'other_user_input'})
    report = {
        'stage': 6, 'kind': 'recorded_authoring_usage', 'proof_claim': False,
        'coverage': 'All token_usage_record events in the declared Stage 6 interval; source is local runtime telemetry.',
        'start_turn_id': START_TURN, 'last_source_line': last_index + 1,
        'last_source_ordinal': rows[last_index].get('ordinal'),
        'source_prefix_bytes': len(prefix), 'source_prefix_sha256': digest(prefix),
        'prior_phase_cumulative_tokens': prior, 'ending_cumulative_tokens': ending,
        'totals': totals, 'cumulative_difference_matches_sum': True,
        'usage_record_count': len(selected),
        'records': [{'source_line': i + 1, 'source_record_sha256': digest(lines[i]),
                     'response_id_sha256': digest(p['response_id'].encode()),
                     'turn_id': p['turn_id'], 'usage': p['usage']} for i, p in selected],
        'transcript_event_index': transcript,
        'transcript_event_counts': dict(sorted(Counter(t['item_type'] or t['record_type'] for t in transcript).items())),
        'human_interventions': human, 'human_intervention_count': len(human),
        'automatic_continuations': automatic, 'automatic_continuation_count': len(automatic),
        'accounting_rules': [
            'Add input and output to obtain total; do not add cached-input or reasoning-output subsets again.',
            'All recorded authoring, failures, status replies, and approval waits within this interval are included.',
            'Common preparation is reported once and is not allocated to conditions by guess.',
            'Fixed-source verifier runs make no model calls; this does not imply zero authoring cost.',
            'Post-cutoff activity is outside this interval; this is not a whole-project final bill.',
            'Prior-phase cumulative usage is disclosed separately and is not added again to Stage 6 totals.',
        ],
        'limits': [
            'Runtime usage records are not independently signed provider billing attestations.',
            'The local session retains available prompt/response events; the public index exposes hashes and counts only.',
            'Private instructions, reasoning text, credentials, and unrelated historical content are not published.',
            'The event log is not an export of every internal provider transport request body.',
            'No dollars, token savings, LLM quality improvement, or cross-project extrapolation is inferred.',
        ],
    }
    directory = ROOT / 'results/stage6/accounting'
    directory.mkdir(parents=True, exist_ok=True)
    name = 'through-' + str(report['last_source_ordinal']) + '.json'
    encoded = canonical(report)
    path = directory / name
    if path.exists():
        assert path.read_bytes() == encoded
    else:
        path.write_bytes(encoded)
    (ROOT / 'results/stage6/accounting.json').write_bytes(encoded)
    print(json.dumps({'snapshot': path.relative_to(ROOT).as_posix(), 'tokens': totals,
                      'usage_records': len(selected), 'human_interventions': len(human),
                      'automatic_continuations': len(automatic), 'sum_matches_cumulative': True}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
