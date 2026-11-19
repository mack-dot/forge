#!/bin/bash
# second run of every case (log name suffix -run2)
D=<REPO>/results/night-shift-20261119/orch-C/c21-sink2
while read -r n s m; do [ -z "$n" ] && continue; $D/rr.sh "$n-run2" "$s" "$D/work/$n" "$m" | head -1; done <<'L'
a21-recover-deep a21_files.ts recover-deep
a21-recover-one a21_files.ts recover-one
a23-swap-commit a23_inode.ts swap-commit
a25-d14-none a25_anchor.ts d14-none
a27-stale-z1del a27_head.ts stale-z1del
a27-crash-pre a27_head.ts crash-pre
d19-lw d19_restore.ts lw
d19-all d19_restore.ts all
d19-lost-both d19_restore.ts lost-both
a24-control a24_map.ts control
a24-sqlrename a24_map.ts sqlrename
a24-midswap a24_map.ts midswap
a24-jmidswap a24_map.ts jmidswap
a24-jrename a24_map.ts jrename
a24-rawkeep a24_map.ts rawkeep
a25-d14-head a25_anchor.ts d14-head
a25-d14-stale a25_anchor.ts d14-stale
a25-boundary a25_anchor.ts boundary
a25-stale-eq a25_anchor.ts stale-eq
a25-stale-roll a25_anchor.ts stale-roll
a25-midrun a25_anchor.ts midrun
a27-iface-z1del a27_head.ts iface-z1del
a27-crash-post a27_head.ts crash-post
a27-two-writers a27_head.ts two-writers
a27-reenter a27_head.ts reenter
a23-swap-run a23_inode.ts swap-run
a23-hardlink a23_inode.ts hardlink
a21-cookie a21_files.ts cookie
a21-dispjournal a21_files.ts dispjournal
d19-all-outside d19_restore.ts all-outside
d19-lost-ledger d19_restore.ts lost-ledger
d17-control d17_lock.ts control
d17-theft d17_lock.ts theft
d17-stop-retry d17_lock.ts stop-retry
d17-throw d17_lock.ts throw
L
