# Exact next action: one directory setup and one additional hosted run

Status: proposal only. No second run is authorized or started.

The authorized run42292059389 completed with step exit78. The pinned macOS ARM64
image passed /var/tmp access,mkstemp,read/write,process,memory and negative
permission controls. mkdir("/Users/mackianni",0700) returned EACCES13.
The pinned HOL executable,heaps and unchanged SAT diagnostic did not execute.

Prepared file: [m1-macos-preflight-retry-proposal.yml](m1-macos-preflight-retry-proposal.yml).
Exact diff: [retry-proposal.diff](retry-proposal.diff).
SHA256: ed975f35b2016f84fcb814a4cdb81997f94eb8beb3b4d6e4fde0b74c9640d9fe.

Requested approval covers one further push/run on the existing proposal branch
and exactly two privileged setup commands in its disposable GitHub VM:

```text
/usr/bin/sudo -n /bin/mkdir -m 700 /Users/mackianni
/usr/bin/sudo -n /usr/sbin/chown <runner-uid>:<runner-gid> /Users/mackianni
```

The script obtains numeric UID/GID from the non-root runner process. mkdir fails
if the path exists. chown is not recursive. No existing directory permissions,
security policy,user account,protected source or machine-wide service changes.
HOL and MiniSat remain non-root. Their exact bytes,heap chain,theorem input,
image pin,input commit,empty token permissions and resource bounds are retained.

The diff also corrects a latent workflow-generation error: INPUT_8435 becomes
INPUT_MANIFEST_BYTES. The first run stopped before reaching this key lookup;
this bug did not cause its observed EACCES failure. Both records are preserved.

The additional run would recheck the environment and input hashes,then execute
the unchanged SAT diagnostic once if all prerequisites pass. It has a120 CPU
second per-process limit,1GiB HOL heap limit,32MiB per-stream file limit and
15-minute operational ceiling. A ceiling expiry is an execution failure,not
a proof result. Standard public-repository macos-15 remains the documented free
class. The first run reports0 billable milliseconds and12 seconds run duration.

Approval is required because the user's current authorization covers one hosted
run,and earlier constraints forbid unapproved privileged workarounds. That one
run is now complete. The existing workflow is not changed by this proposal.
No automatic retry,Stage12,release signing,deployment or protected edit.
M1 remains open; physical ffiread correspondence unproved; end_to_end=false.
