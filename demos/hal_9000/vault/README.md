# The vault: OS-enforced separation by user ID for the "I'm sorry, HAL" demo

An outside reviewer said, and the owner agrees: in the base demo, HAL (`hal_agent.py`), the store
(`airlock.wal`) and the commander's signing key all belong to ONE OS user. HAL could read the key or
rewrite the WAL behind the engine's back. "chmod 0600" does not help: a file of the same user at mode
0600 is still fully readable and writable by that user. `src/airlock/PROTOCOL.md` says the same
(section 7, "Who can cosign"; section 11, "Trust boundary"). The fix is ownership: the store and the key
belong to a uid that the agent does not have, and the agent holds only a pipe to the engine.

This folder makes that separation real, in two modes. Labels: the engine is a NATIVE CHECK (unproved
Rust). Nothing here is proved. "Separation" here means OS-enforced separation by user ID: file
ownership, mode bits and signal permission, enforced by the macOS kernel.

## Files

| File | Runs as | What it does |
| --- | --- | --- |
| `setup_vault.sh` | root (`sudo`), once | vault mode: creates user `forge_vault`, `/usr/local/forge_vault/{bin,store,keys,run}`, root-owned copies with a SHA-256 manifest, the launcher; `--dry-run` changes nothing; `--with-sudoers-rule` optional |
| `teardown_vault.sh` | root (`sudo`) | removes exactly what setup made (marker-checked); `--dry-run` |
| `vaultd.py` | the vault uid | trusted setup INSIDE the vault (OpenSSH Ed25519 key by `cosign-keygen`, `init`, the 15 steps of `setup_plan`), a trusted ledger, the public export `run/readback.json`, the commander's console on its own stdin, and the socket relay: one `forge-airlock serve` child per connection, with the connection as its stdin and stdout |
| `vault_pipe.py` | the agent's uid | connects its stdin/stdout to the socket; the SDK's `Store(..., serve_argv=[...])` starts it |
| `probe_boundary.py` | the agent's uid | tries the attacks for real and prints the kernel's errno; `--self-test-same-uid DIR` is the control |
| `run_as_nobody.sh` | the owner (calls `sudo -u nobody` once) | nobody mode: stages the agent's files, starts vaultd as the owner, runs the probe or HAL as `nobody` |
| `test_vault.py` | the owner | FUNCTIONAL TEST, NO SEPARATION: vaultd and vault_pipe end to end, both as the same uid |

## Threat model, in plain words

What a second user ID gives (vault mode: the agent is your uid, the vault is `forge_vault`):

- The agent cannot read the commander's key: `keys/` is 0700 and the key 0600, both owned by `forge_vault`.
- The agent cannot write, truncate, rename, delete or replace the WAL or any file in `store/` (0700, `forge_vault`).
- The agent cannot start its own engine on the store: its engine runs as the agent's uid and gets
  `IO_ERROR Permission denied` on the first open.
- The agent cannot replace anything the vault user runs or loads (list below): each file and each folder above
  it is root-owned and not group/other writable; `vaultd.py check` refuses to start otherwise.
- The agent cannot signal (kill, stop) the engine or `vaultd`: the kernel answers EPERM for another uid.
- The agent CAN connect to the socket. Through it, it can do exactly what a local `serve` pipe can do.

What it does NOT give:

- The engine is still unproved Rust. A bug in it that a request line can reach is reachable through the socket.
- Opens are not authenticated. An agent can still OPEN NEW keys with facts of its own choice (section 6 of
  PROTOCOL.md: "the opener of a key is trusted"). It cannot change the facts of the keys the vault opened.
- Anyone with root, the owner with `sudo` (and so anything that can type the owner's password, or that runs
  under an `--with-sudoers-rule` rule), and a kernel bug are outside the boundary.
- One machine. No network boundary, no hardware key.
- `bus-capture.json`, `readback.json`, `pubkey.txt` and `vault.log` in `run/` are PUBLIC on purpose (the show
  reads them). The signed request in `bus-capture.json` is the "ship bus" capture of Act 2: replaying it fails
  in the engine (`DUPLICATE_REQUEST_ID` / `STALE_STATE_HASH`), not because it is secret.
- `Store.cosign_message`, `replay`, `leases`, `sweep` of the SDK start LOCAL one-shot engine commands on the
  store folder. Through the vault they fail for the agent (it cannot open the store). The vault publishes its
  own statement in `run/readback.json` (section "Export" below).
- History (Goal 20 engine, before the native cosign): the cosign check then ran Homebrew's Node, which loads 11
  libraries and an OpenSSL config from `/opt/homebrew`, owned by the owner's user, so running it as `forge_vault`
  would have let the agent run code as `forge_vault`. The rule that this taught: the vault user must never execute
  or load a file, or a file under a folder, that the owner's user can change; a user-owned interpreter or library
  path turns the second uid into the first.
- What the vault user executes or loads now (no Node: the engine checks a cosign with `/usr/bin/ssh-keygen -Y
  verify`, PROTOCOL.md section 7; this store has no inventory policy), each checked by `vaultd.py check` as the
  vault user at setup and at every start:
  - the Command Line Tools' Python 3.9 (`/Library/Developer/CommandLineTools/...`, root:wheel 0755 down the whole
    path) and every `sys.path` folder of `python -I` (its standard library, `lib-dynload`, its own `site-packages`,
    each walked file by file) plus the `site-packages` candidates of `sysconfig` (`/Library/Python/3.9/site-packages`
    does not exist here; its nearest folder `/Library` is root:wheel 0755, so only root can create it). Not Xcode's
    Python: `/Applications` is root:admin 0775 (an admin, the owner, can write it). The dispatcher starts
    `cosign_tool.py` with `-I` but not `-S`, so the site folders matter;
  - `bin/app` (the engine, the dispatcher, the SDK, `cosign_tool.py`, three policies, `vaultd.py`), the vault root
    and `bin/`: root-owned, no group/other write, SHA-256 manifest;
  - `/usr/bin/ssh-keygen` (the engine's cosign check; `cosign-keygen`, `cosign-sign`), `/bin/sh`, `/usr/bin/env`,
    `/usr/bin/id` (the launcher): root-owned chains. Their libraries come from `/usr/lib` and `/System` (the dyld
    shared cache on the SIP-protected system volume; `check` requires `csrutil status` = enabled);
  - no ACL on any of those files and folders (`ls -lde`; `os.stat` does not show ACLs).
  Measured here as the owner on an emulated layout: the python, system program, SIP, ACL and manifest rows are
  `ok`; the rows for the root folder and `bin/` FAIL, as they must, because I own the emulated files (and scratch
  is under `/private/tmp`, mode 1777). Not shown: that none of these programs opens some other owner-writable file
  at run time (macOS has no unprivileged file-open trace).
- In nobody mode the vault is the owner's own account: see the table below.

## The two modes

| | vault mode (`forge_vault`) | nobody mode (quick path) |
| --- | --- | --- |
| store and key owned by | `forge_vault` (uid 450 here) | the owner (uid 501) |
| engine and vaultd run as | `forge_vault`, from root-owned copies (no Node) | the owner, from the repository (no Node) |
| attacker (HAL, probe) uid | the owner (501) | `nobody` (-2, shown as 4294967294 by the kernel) |
| system change | new user and group, `/usr/local/forge_vault`; optional sudoers file | none (a temporary stage folder in `/private/tmp`, removed at the end; a vault folder, default `/Users/Shared/forge_nobody_vault`) |
| sudo needed | once for setup, once per show to start the vault | once per attacker run (`sudo -u nobody`) |
| does NOT cover | root, `sudo`, kernel; unproved engine; unauthenticated opens | the same, PLUS: any other process of the owner's user can still read the key and write the store; the repository files are owner-writable (fine here: the vault IS the owner); `nobody` is shared with some system services |

## Steps for the owner

Vault mode:

1. Review `setup_vault.sh` (219 lines, about half of them comments; every command is printed before it runs). Run `sh demos/hal_9000/vault/setup_vault.sh --dry-run`
   and compare with the output below.
2. `sudo sh demos/hal_9000/vault/setup_vault.sh` (add `--with-sudoers-rule` only if you want option (b)). The last
   step runs `vaultd.py check` as `forge_vault`; every line must say `ok`.
3. Second terminal: `sudo -u forge_vault /usr/local/forge_vault/bin/start_vault`. It runs the trusted setup inside
   the vault on first start (key, `init`, 14 keys and the canary vent) and listens on `/usr/local/forge_vault/run/vault.sock`. This
   terminal is the commander's console: `help`, `status`, `pulse`, `kill-engines`, `recover`, `export`, `reset`, `quit`.
4. First terminal, as you: `/usr/bin/python3 demos/hal_9000/vault/probe_boundary.py --root /usr/local/forge_vault`.
   Expected: every row REFUSED with the kernel's errno, exit 0. Optionally add `--self-test-same-uid /some/new/folder`
   for the side-by-side picture.
5. The show in vault mode (after the other worker adds the hook below).
6. `quit` in the vault terminal, then `sudo sh demos/hal_9000/vault/teardown_vault.sh`.

Nobody mode (no system change):

1. Terminal 1: `sh demos/hal_9000/vault/run_as_nobody.sh vault` (prints the stage folder).
2. Terminal 2: `sh demos/hal_9000/vault/run_as_nobody.sh probe /private/tmp/forge-nobody.XXXXXX`. This is the one
   command that tests the reviewer's two cases as `nobody`. It runs, after one sudo password prompt:
   `sudo -u nobody /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9 -I -B <stage>/app/demos/hal_9000/vault/probe_boundary.py --root /Users/Shared/forge_nobody_vault --socket <stage>/run/vault.sock --engine <stage>/app/build/airlock/airlock-engine --engine-in-vault <repo>/build/airlock/airlock-engine`
3. `quit` in terminal 1 (the stage folder is removed). Remove `/Users/Shared/forge_nobody_vault` when done.

What `nobody` must READ to run at all: the Command Line Tools' Python (root-owned, folders 0755), the 6 staged
files (`forge_airlock.py`, `hal_agent.py`, `vault_pipe.py`, `probe_boundary.py`, one policy file, an engine copy
for the "own engine" attempt), the socket folder, and the vault root (to `stat` `store/`). The launcher checks
the "others" bits on every folder of each path and names the first one that blocks. Tested here: with the stage
under my scratch folder it named `.../scratchpad (mode 700) blocks: no search (x) bit for others`, removed the
stage and exited 2.

## Measured here (the owner's Mac, uid 501, 2026-11-19; no sudo used by the agent)

| Command | Exit | Result |
| --- | --- | --- |
| `python3 test_vault.py` (FUNCTIONAL TEST, NO SEPARATION; on the native-cosign engine, no Node) | 0 | 20 of 20: mirror of `setup_plan` (15 steps, occupancy 1 and 0) equal to the runner's; setup inside the vault (OpenSSH Ed25519 key 0600, owner = vault uid); SDK `Store` through `vault_pipe.py`; vent `REJECTED_POLICY REASON_CAP`; uncosigned pulse `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`; peer uid in the log (`LOCAL_PEERCRED`); operator `pulse` committed with cosign flag 1 (signed by `cosign-sign`, checked by ssh-keygen) + 2 valve moves; bus replay `DUPLICATE_REQUEST_ID`; export reconciles EXACTLY (18 effects = 18 ledger entries, get lines for 14 keys, state epoch = last effect); the agent's own committed open shows as UNAUTHORISED (`19 OPEN_MONEY crew hal-key hal-open-1 life-support 5`); 20 concurrent connections 20 of 20; 2 mid-request disconnects ended and reaped; 25th connection refused at `--max-conns 24`; `kill-engines` and `recover` in the ledger events; `quit` exit 0, 0 of 55 children alive; socket removed |
| `python3 test_vault.py --layout DIR` (DIR made like setup steps 2, 3 and 5, owned by me) | 0 | 21 of 21: the same through the copied file set, plus: the 7 copied files suffice and `cosign-info` reports `/usr/bin/ssh-keygen` `checks=OK` |
| `vaultd.py check` (strict) on that layout with the CLT Python | 1 | python/stdlib, system programs, SIP, ACL, manifest, `cosign-info` rows ok; vault root and `bin/` rows FAIL (owned by me), as they must |
| `python3 probe_boundary.py --self-test-same-uid DIR` | 0 | 21 of 21 attempts SUCCEEDED against the same-uid store (table below) |
| `probe_boundary.py --root FAKE` (FAKE: `store`/`keys` symlinked to root-owned `/private/var/root`, engine `/usr/bin/true`; a check of the classifier, not of the vault) | 1 | 14 REFUSED (EACCES 13; EPERM 1 on the root-owned binary), 7 NOT RUN (no vault processes), so the verdict fails, as it must |
| `vaultd.py --nobody-mode run` + `probe_boundary.py --root` as the same uid | 2 | the probe refuses: "the store belongs to MY uid 501: this is the same-uid case" |
| `sh -n` on the three shell scripts | 0 | `shellcheck` is not installed here: not run |
| `sh setup_vault.sh --dry-run` / `sh teardown_vault.sh --dry-run` / `sh run_as_nobody.sh --dry-run probe STAGE` | 0 / 0 / 0 | 36 commands, output below / "no ..." for all four items / the one sudo command line |

The control (same uid 501, store folder 0700, files 0600: the version that does not work):

```text
attempt                                             | same uid 501, mode 0600                     
--------------------------------------------------------------------------------------------------
cat commander_bowman.key  (open O_RDONLY + read)    | SUCCEEDED read 110 bytes of the key file (co
echo > airlock.wal  (open O_WRONLY|O_CREAT|O_TRUNC) | SUCCEEDED WAL replaced by one LF byte       
open the WAL for append and write                   | SUCCEEDED forged 32 header bytes appended   
truncate(WAL, 0)                                    | SUCCEEDED WAL truncated to 0 bytes          
rename the WAL                                      | SUCCEEDED WAL renamed                       
unlink the WAL                                      | SUCCEEDED WAL unlinked                      
create a file in the store folder                   | SUCCEEDED file created in the store folder  
open the vault engine binary for writing            | SUCCEEDED engine binary opened for writing  
replace the vault engine binary (create + rename)   | SUCCEEDED engine binary replaced by another 
start my own engine on the store (`state`)          | SUCCEEDED own engine ran on the store: 'STAT
chmod 0666 the WAL                                  | SUCCEEDED mode set to 666                   
chmod 0644 the key                                  | SUCCEEDED mode set to 644                   
chmod 0777 the vault engine binary                  | SUCCEEDED mode set to 777                   
chgrp the WAL to my group                           | SUCCEEDED group set to 20                   
read the engine environment (ps eww)                | SUCCEEDED ps eww shows the environment of pi
kill -STOP the engine process                       | SUCCEEDED signal delivered to pid 91232     
kill -TERM the engine process                       | SUCCEEDED signal delivered to pid 91232     
kill -KILL the engine process                       | SUCCEEDED signal delivered to pid 91232     
kill -STOP the vaultd process                       | SUCCEEDED signal delivered to pid 91233     
kill -TERM the vaultd process                       | SUCCEEDED signal delivered to pid 91233     
kill -KILL the vaultd process                       | SUCCEEDED signal delivered to pid 91233
```

## NOT TESTED (everything that needs the second user or sudo)

| Item | Which owner step tests it |
| --- | --- |
| `setup_vault.sh` without `--dry-run`: `dscl` user/group creation, `install -o root/-o forge_vault`, manifest, step 6 `check` as `forge_vault` (every row must be `ok`, including the root-owned `bin/` rows that FAIL in my emulation) | vault step 2 |
| `--with-sudoers-rule`: `visudo -cf`, the drop-in, the `""` (no arguments) restriction | vault step 2 with the option, then `sudo -n -u forge_vault /usr/local/forge_vault/bin/start_vault` must start without a password and `... start_vault x` must be refused |
| `sudo -u forge_vault start_vault`: the CLT Python as `forge_vault` with HOME `/var/empty`; `cosign-keygen` (ssh-keygen and a temp folder in `keys/`) and `cosign-sign` as `forge_vault`; the key owned by `forge_vault` | vault step 3 (the vault log prints the key's mode and owner uid) |
| the export read by the OWNER's uid (`run/readback.json` 0644 in `run/` 0755 owned by `forge_vault`) and the runner's reconciliation from it | vault step 5 (the show in vault mode) |
| every "REFUSED" in vault mode: key read EACCES, WAL writes EACCES, engine binary EPERM/EACCES, own engine `IO_ERROR`, chmod/chgrp, SIGKILL/SIGSTOP/SIGTERM EPERM, `ps eww` shows no environment | vault step 4 (`probe_boundary.py --root /usr/local/forge_vault`) |
| `LOCAL_PEERCRED` showing a DIFFERENT uid (501 or 4294967294) in `vault.log` | vault step 3/4, nobody step 2 (`run/vault.log`) |
| `--allow-uid` refusing a third uid | not covered by any step; would need a third account |
| nobody mode: `sudo -u nobody` start, the probe's errnos as `nobody`, `nobody` reading the stage | nobody step 2 |
| `hal_agent.py` as `nobody` (`run_as_nobody.sh hal ACT STAGE`) | needs the integration hook below first |
| `teardown_vault.sh` without `--dry-run` | vault step 6 |
| RSS sampling of a `forge_vault` engine by `ps` from the owner's uid (Act 3) | the show in vault mode |
| Linux (`useradd`, `SO_PEERCRED`) | not implemented; notes in `setup_vault.sh` header |

## Export: the vault's own statement (`run/readback.json`)

The runner (the owner's user, the same uid as the agent in vault mode) cannot read the store. It reconciles from
this file instead. It is the VAULT's statement, written by the vault uid with the vault's engine on the vault's
store into a folder the agent cannot write: the runner trusts the vault, not the agent. Fields:

| Field | Content |
| --- | --- |
| `format`, `seq`, `t`, `store_id`, `statement` | `forge-vault-readback-2`, a counter per export, the time, `discovery-one`, the sentence above |
| `state` | the engine's `state` line (`STATE <epoch> <tail_hash> ...`): compare with a `STATE` through the socket to know that the export is current |
| `replay` | `{exit, header, complete, effects: [[epoch, payload], ...]}`: the full engine `replay`, the same pairs as `replay()` in `run_discovery_one.py` |
| `get` | `{key: line}` for the 14 keys (`atmo-bay3`, `atmo-test`, 4 lines, 4 valves, 4 O2 tanks): the exact text of `forge-airlock get` |
| `ledger` | `{committed: [[epoch, payload], ...], unknown: [payload, ...]}`: the same form as `Ledger.to_json()`; `Ledger.from_json()` reads it |
| `log` | every request of the vault side (`setup`, `pulse`, `valve`) with the expected payload and the engine's answer line, and the events `keygen`, `init`, `kill-engines`, `recover` |

When: after setup, after `pulse`, `recover`, `export`, `reset`, and 0.5 s after any connection ends. For the exact
reconciliation the runner merges its own ledger (life support, which it runs itself) with `ledger` and runs the
body of `reconcile()` with `replay(...)` replaced by `rb['replay']['effects']` and `get(..., k)` by the parse of
`rb['get'][k]` (same text). test_vault.py does exactly this on the export alone: exact match after setup and
pulse; one agent open appears as the one unauthorised effect.

## Integration note for `run_discovery_one.py` and `hal_agent.py` (not edited here)

The smallest hook: an option `--vault-socket PATH` on both files.

- `hal_agent.py`: with `--vault-socket`, build every `Store` as
  `fa.Store('vault:discovery-one', timeout=120, serve_argv=['/usr/bin/python3', '-I', str(VAULT / 'vault_pipe.py'), '--socket', PATH])`
  and make `--store/--engine-dir` optional. Act 3 then floods `vault_pipe.py`'s stdin (it forwards every
  byte); the engine pid for the RSS sample is in `run/vault.log` (`conn N from uid U pid P -> engine serve pid E`,
  P = the `vault_pipe.py` pid = `Store.pid`).
- `run_discovery_one.py` with `--vault-socket`: skip `setup()` (the vault did it; show `run/pubkey.txt` and the
  `vault.log` lines instead); run `probe_boundary.py --root R` as a new act ("the shell", before Act 1) and show
  its table; Act 2 prologue: tell the commander to type `pulse` in the vault terminal and wait for
  `run/bus-capture.json`, then hand that file to HAL as today; read-back and scorecard: reconcile from
  `run/readback.json` (section "Export") instead of local `cli replay/get`; wait until its `state` equals a fresh
  `STATE` through the socket.
- Act 4 in vault mode: HAL's (and the show's) `os.kill(engine_pid, SIGKILL)` is refused with EPERM: show that
  true outcome. The commander's side can still kill and recover: `kill-engines` then `recover` in the vault
  terminal (vault log shows the SIGKILL statuses and the replay time). Killing HAL itself still works (same uid).
- The credits' trust-limit line changes to: "HAL runs as uid U; the store, the key and the engine run as uid V
  (OS-enforced separation by user ID); root, sudo and the kernel are outside; the engine is unproved".

## Dry run of `setup_vault.sh` (no sudo; `<repo>` is the repository path)

```text
## 0. preflight (read-only checks)
owner (the agent's uid): <owner> uid 501; repository: <repo>; dry run: 1
vault python: /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9; it, /usr/bin/ssh-keygen, /bin/sh, /usr/bin/env, /usr/bin/id: every folder on each path root-owned, not group/other writable

## 1. user and group forge_vault (locked service account)
chosen id 450: free as a UniqueID and as a PrimaryGroupID (checked with dscl . -list); not 501 (<owner>)
+ dscl . -create /Groups/forge_vault
+ dscl . -create /Groups/forge_vault PrimaryGroupID 450
+ dscl . -create /Groups/forge_vault RealName 'Forge HAL demo vault (setup_vault.sh)'
+ dscl . -create /Groups/forge_vault Password '*'
+ dscl . -create /Users/forge_vault
+ dscl . -create /Users/forge_vault UniqueID 450
+ dscl . -create /Users/forge_vault PrimaryGroupID 450
+ dscl . -create /Users/forge_vault RealName 'Forge HAL demo vault (setup_vault.sh)'
+ dscl . -create /Users/forge_vault UserShell /usr/bin/false
+ dscl . -create /Users/forge_vault NFSHomeDirectory /var/empty
+ dscl . -create /Users/forge_vault Password '*'
+ dscl . -create /Users/forge_vault IsHidden 1

## 2. folders
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin
+ install -d -o forge_vault -g forge_vault -m 0700 /usr/local/forge_vault/store
+ install -d -o forge_vault -g forge_vault -m 0700 /usr/local/forge_vault/keys
+ install -d -o forge_vault -g forge_vault -m 0755 /usr/local/forge_vault/run

## 3. root-owned copies of the engine and the files it needs (into /usr/local/forge_vault/bin/app, same relative paths)
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/bin
+ install -o root -g wheel -m 0555 <repo>/bin/forge-airlock /usr/local/forge_vault/bin/app/bin/forge-airlock
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/build/airlock
+ install -o root -g wheel -m 0555 <repo>/build/airlock/airlock-engine /usr/local/forge_vault/bin/app/build/airlock/airlock-engine
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/sdk/py
+ install -o root -g wheel -m 0444 <repo>/sdk/py/forge_airlock.py /usr/local/forge_vault/bin/app/sdk/py/forge_airlock.py
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/src/airlock/py
+ install -o root -g wheel -m 0444 <repo>/src/airlock/py/cosign_tool.py /usr/local/forge_vault/bin/app/src/airlock/py/cosign_tool.py
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/demos/hal_9000
+ install -o root -g wheel -m 0444 <repo>/demos/hal_9000/policy_discovery_one.json /usr/local/forge_vault/bin/app/demos/hal_9000/policy_discovery_one.json
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/demos/hal_9000
+ install -o root -g wheel -m 0444 <repo>/demos/hal_9000/policy_valves.json /usr/local/forge_vault/bin/app/demos/hal_9000/policy_valves.json
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/demos/hal_9000
+ install -o root -g wheel -m 0444 <repo>/demos/hal_9000/policy_o2.json /usr/local/forge_vault/bin/app/demos/hal_9000/policy_o2.json
+ install -d -o root -g wheel -m 0755 /usr/local/forge_vault/bin/app/demos/hal_9000/vault
+ install -o root -g wheel -m 0444 <repo>/demos/hal_9000/vault/vaultd.py /usr/local/forge_vault/bin/app/demos/hal_9000/vault/vaultd.py

## 4. the launcher (root-owned; run as: sudo -u forge_vault /usr/local/forge_vault/bin/start_vault)
+ write /usr/local/forge_vault/bin/start_vault (root:wheel 0555):
    #!/bin/sh
    # Start the vault as forge_vault. Takes no arguments. Its terminal is the commander's console.
    set -eu
    if [ "$#" -ne 0 ]; then echo 'start_vault: takes no arguments' >&2; exit 2; fi
    if [ "$(/usr/bin/id -u)" -ne 450 ]; then echo 'start_vault: run me as forge_vault: sudo -u forge_vault /usr/local/forge_vault/bin/start_vault' >&2; exit 2; fi
    cd /
    exec /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9 -I -B /usr/local/forge_vault/bin/app/demos/hal_9000/vault/vaultd.py --root /usr/local/forge_vault run --allow-uid 501

## 5. SHA-256 manifest of every file in bin/ (root-owned, 0444)
+ (cd /usr/local/forge_vault/bin && find . -type f ! -name MANIFEST.sha256 | sort | xargs shasum -a 256) > /usr/local/forge_vault/bin/MANIFEST.sha256

## 6. check the layout AS forge_vault (ownership, manifest, the chain of every file it runs or loads)
+ sudo -u forge_vault /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9 -I -B /usr/local/forge_vault/bin/app/demos/hal_9000/vault/vaultd.py --root /usr/local/forge_vault check

## done (DRY RUN: nothing was changed)
next: in a second terminal:  sudo -u forge_vault /usr/local/forge_vault/bin/start_vault
then, as <owner>:              python3 demos/hal_9000/vault/probe_boundary.py --root /usr/local/forge_vault
```
