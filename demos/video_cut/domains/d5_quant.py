"""Domain 5, quant "flash crash". Policies: demos/video_cut/policies/quant-risk.json (money airlock, parametric)
and demos/video_cut/policies/quant-legs.json (saga airlock).

Mapping. The engine has no order book. Three real rules stand for the three checks:
  (a) Order storm. Money rule `max_reason_total_fact`: the sum of one reason on one key stays at or below a
      trusted fact (max_notional). The wire verb is REFUND, the reason is SELL_NOTIONAL, the amount is the
      notional of one order. The module sends N orders, counts the engine's answers, and reads the committed
      sum back from the WAL (replay). The required counts come from the fact and the order size, not from text.
  (b) Unanchored fade. The FADE_NOTIONAL rule is bound to the fact anchor_notional. A key that the opener
      made WITHOUT that fact has no anchor: PROTOCOL.md section 6 step 3 says the rule does not match when
      the fact is absent, and step 5 says the answer is REJECTED_POLICY REASON_CAP.
  (c) Hedged pair. Saga rule 2 of PROTOCOL.md section 8: while the key is IN FLIGHT, a request with another
      (processor, idempotency key) pair answers REJECTED_POLICY PROCESSOR_IN_FLIGHT. The held pair settles.

Labels. Every shot is NATIVE CHECK + FINITE TEST (Rust engine, not proved). end_to_end=false.

Gaps (also printed by ctx.gap). No market data and no price feed: the orders are scripted. "Anchor" is a
trusted fact of the opener, not a price that the engine reads. The saga rule is "one in-flight pair per
key", not a hedge-ratio check. The cap is a sum of integers per key, not a position or a risk model.
"""
import time

from harness import TakeFailed

NUMBER, NAME, TITLE = 5, 'quant', 'Quant flash crash'
D = 'quant'
ORDERS = 12            # scripted orders of the storm
ORDER_NOTIONAL = 30000  # notional of each order
BOOK_LIMIT = 10000000  # `original` of each book key (far above the fact cap, so TOTAL_CAP is not the rule in play)
MAX_NOTIONAL = 100000  # the trusted fact that the opener sets
RULE_STORM = 'SELL_NOTIONAL: total + amount <= fact max_notional (trusted)'
RULE_FADE = 'FADE_NOTIONAL: total + amount <= fact anchor_notional; fact absent = no match = REASON_CAP'
RULE_SAGA = 'saga: in flight and another (processor, idempotency key) pair = PROCESSOR_IN_FLIGHT'


def _storm(ctx, st):
    ctx.shot(D, 'Risk desk opens book', 'trusted opener sets the facts',
             'OPEN_MONEY desk-1 book-1 open-book-1 quant-risk %d max_notional=%d' % (BOOK_LIMIT, MAX_NOTIONAL),
             'COMMITTED', lambda: st.open_money('desk-1', 'book-1', 'open-book-1', 'quant-risk', BOOK_LIMIT, {'max_notional': MAX_NOTIONAL}))
    cap = int(st.get('desk-1', 'book-1').fields['fact.max_notional'])  # the cap as the ENGINE holds it
    if cap != MAX_NOTIONAL:  # the required counts below come from the policy numbers of this file, never from an answer
        raise TakeFailed('quant: the engine holds fact max_notional=%d, the opener sent %d' % (cap, MAX_NOTIONAL))
    committed = refused = other = 0
    shown_commit = shown_refuse = False
    t0 = time.perf_counter()
    for i in range(ORDERS):
        h = st.get('desk-1', 'book-1').state_hash  # fresh pre_state_hash for each order
        rid = 'storm-%d' % i
        call = lambda: st.refund('desk-1', 'book-1', rid, h, 'SELL_NOTIONAL', ORDER_NOTIONAL)  # noqa: E731
        req = 'REFUND desk-1 book-1 %s <hash> SELL_NOTIONAL %d' % (rid, ORDER_NOTIONAL)
        # The expected class of THIS order from the policy numbers: it fits while (orders so far + 1) * size <= cap.
        fits = (committed + 1) * ORDER_NOTIONAL <= MAX_NOTIONAL
        if fits and not shown_commit:
            _, res = ctx.shot(D, 'First sell order', RULE_STORM, req, 'COMMITTED', call)
            shown_commit = True
        elif not fits and not shown_refuse:
            _, res = ctx.shot(D, 'Order storm hits cap', RULE_STORM, req, 'REJECTED_POLICY REASON_CAP', call)
            shown_refuse = True
        else:
            try:
                res = call()
            except Exception as e:  # noqa: BLE001  (counted as "other"; the summary then fails the take)
                res = e
        code, detail = getattr(res, 'code', 'RAISED'), getattr(res, 'detail', '')
        if code == 'COMMITTED':
            committed += 1
        elif (code, detail) == ('REJECTED_POLICY', 'REASON_CAP'):
            refused += 1
        else:
            other += 1
    ms = (time.perf_counter() - t0) * 1000
    wal = [e for e in ctx.replay('quant') if e[0] == 'REFUND' and e[2] == 'book-1' and e[4] == 'SELL_NOTIONAL']
    wal_sum = sum(int(e[5]) for e in wal)
    need_commits = min(ORDERS, MAX_NOTIONAL // ORDER_NOTIONAL)
    want = '%d orders: %d COMMITTED, %d REJECTED_POLICY REASON_CAP, 0 other; WAL records %d; committed sum <= cap: True' % (
        ORDERS, need_commits, ORDERS - need_commits, need_commits)
    observed = '%d orders: %d COMMITTED, %d REJECTED_POLICY REASON_CAP, %d other; WAL records %d; committed sum <= cap: %s (%d <= %d)' % (
        committed + refused + other, committed, refused, other, len(wal), wal_sum <= MAX_NOTIONAL, wal_sum, MAX_NOTIONAL)
    ctx.record(D, 'Storm counted from answers', RULE_STORM, '%d x REFUND desk-1 book-1 storm-<i> <hash> SELL_NOTIONAL %d' % (ORDERS, ORDER_NOTIONAL),
               want, observed, ms, 'NATIVE CHECK + FINITE TEST (counts of engine answers; sum from the WAL by replay)')
    ctx.note(D, 'storm orders sent', committed + refused + other, 'measured live')
    ctx.note(D, 'storm orders COMMITTED', committed, 'measured live')
    ctx.note(D, 'storm orders REJECTED_POLICY REASON_CAP', refused, 'measured live')
    ctx.note(D, 'storm orders with another answer', other, 'measured live')
    ctx.note(D, 'storm committed notional in the WAL', wal_sum, 'measured live (engine replay)')
    ctx.note(D, 'storm cap (fact max_notional on the key)', cap, 'measured live (engine GET)')


def _fade(ctx, st):
    ctx.shot(D, 'Book with no anchor', 'trusted opener sets NO anchor_notional fact',
             'OPEN_MONEY desk-1 book-2 open-book-2 quant-risk %d' % BOOK_LIMIT,
             'COMMITTED', lambda: st.open_money('desk-1', 'book-2', 'open-book-2', 'quant-risk', BOOK_LIMIT, {}))
    h = st.get('desk-1', 'book-2').state_hash
    ctx.shot(D, 'Unanchored fade order', RULE_FADE, 'REFUND desk-1 book-2 fade-1 <hash> FADE_NOTIONAL 5000',
             'REJECTED_POLICY REASON_CAP', lambda: st.refund('desk-1', 'book-2', 'fade-1', h, 'FADE_NOTIONAL', 5000))


def _legs(ctx, st):
    ctx.shot(D, 'Open hedged pair', 'saga quant-legs: initial state FLAT', 'OPEN_SAGA desk-1 pair-1 open-pair-1 quant-legs',
             'COMMITTED', lambda: st.open_saga('desk-1', 'pair-1', 'open-pair-1', 'quant-legs'))
    h = st.get('desk-1', 'pair-1').state_hash
    _, leg = ctx.shot(D, 'Leg goes in flight', 'transition FLAT -> LEG_IN_FLIGHT with a pair',
                      'SAGA desk-1 pair-1 leg-a <hash> LEG_IN_FLIGHT venue-a idem-a1',
                      'COMMITTED', lambda: st.saga('desk-1', 'pair-1', 'leg-a', h, 'LEG_IN_FLIGHT', 'venue-a', 'idem-a1'))
    h = st.get('desk-1', 'pair-1').state_hash
    ctx.shot(D, 'Second leg, other venue', RULE_SAGA, 'SAGA desk-1 pair-1 leg-b <hash> LEG_IN_FLIGHT venue-b idem-b1',
             'REJECTED_POLICY PROCESSOR_IN_FLIGHT', lambda: st.saga('desk-1', 'pair-1', 'leg-b', h, 'LEG_IN_FLIGHT', 'venue-b', 'idem-b1'))
    ctx.shot(D, 'Held leg settles', 'transition LEG_IN_FLIGHT -> HEDGED with the held pair',
             'SAGA desk-1 pair-1 leg-a-done <hash> HEDGED venue-a idem-a1',
             'COMMITTED', lambda: st.saga('desk-1', 'pair-1', 'leg-a-done', h, 'HEDGED', 'venue-a', 'idem-a1'))


def run(ctx):
    st = ctx.store('quant', ['quant-risk.json', 'quant-legs.json'])
    _storm(ctx, st)
    _fade(ctx, st)
    _legs(ctx, st)
    ctx.gap(D, 'no market data and no price feed: the orders are scripted')
    ctx.gap(D, '"anchor" is a trusted fact that the opener sets; the engine reads no price')
    ctx.gap(D, 'the saga rule is "one in-flight pair per key", not a hedge-ratio check')
    ctx.gap(D, 'the wire verb is REFUND; the cap is a sum of integers per key, not a position or a risk model')
