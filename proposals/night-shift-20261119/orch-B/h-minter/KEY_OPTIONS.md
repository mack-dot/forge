# Issuer key persistence and issuer identity: options for the owner (h-minter, G3; C-ATT-05, C-ATT-14)

Nothing here is implemented. minter.ts keeps today's behaviour: a new Ed25519 TEST key at every start.

## A. Key persistence (C-ATT-05: a restart makes a new key; the sink's pinned key no longer matches)
Today: liveness dead end by design. After an issuer restart, the sink refuses every new token (wrong key) until
an operator re-pins the sink to the new public key. The v6 audit also refuses a legitimate store after a rotation,
because it checks old rows against the one pinned key.

Options (each one needs an owner decision and a key ceremony; no option is chosen here):
1. Key file outside the repository. PKCS#8 PEM, mode 0600, owner = a dedicated issuer user, directory 0700, path from
   a fixed configuration file (not from the caller). Cost: low. Risk: any process of that user, a backup, or a
   root user reads the key. Needs: refuse to start if the mode is wider than 0600 or the owner is wrong.
2. Operating-system keychain (macOS Keychain item with an access list for the issuer binary only; Linux: kernel
   keyring or a secret service). Cost: medium; platform code. Ed25519 signing still happens in the process after the
   key is read, so process isolation stays the boundary.
3. Hardware key (YubiKey/HSM/TPM with Ed25519 support, or a cloud KMS). The private key never enters the process.
   Cost: high; latency per signature; a device dependency. Strongest against key theft.

What every option needs in addition:
- The issued-memory of IssueOnce must persist WITH the key (SINGLE_USE.md section 6). A persistent key with a
  forgetful memory lets the same request id be signed with a different candidate after a restart.
- Rotation: the sink and its audit need the LIST of public keys with their validity: `{publicKeyPem, validFromSeq,
  retiredAtSeq|null}`. A stored row is valid if its signature verifies under the key that was active at its sequence
  number. New commits accept only the current key. The key list itself must be pinned outside the sink database
  (in the external anchor or in configuration), or a database writer could add a key.
- A revocation rule: a retired key that leaked must make rows signed after a stated point invalid.

## B. What "the checker id identifies the issuer" needs (C-ATT-14)
checkerSha256 = SHA-256 of canon({core module, encoding.ts, minter.ts}) (encoding.ts:84-87). It does NOT cover:
bignumber.js (required by minter.ts AND by the core module from the core module's own directory), tsx, Node itself,
OpenSSL, or anything that NODE_OPTIONS / NODE_PATH / a preload can add. The red team ran a shim bignumber.js inside the
key-holding process while the issuer reported the pinned id (p4_module_identity.ts, exit 1; also on my tree: exit 1).
Every sentence "the checker id identifies the issuer" needs two named assumptions:
- CLOSED-LAUNCH: the issuer is started by a fixed launcher with a scrubbed environment (no NODE_OPTIONS, no NODE_PATH,
  no preload from outside), a fixed working directory, and a fixed path of the core module.
- FIXED-DEPS: the dependency tree that Node resolves (node_modules, tsx, the Node binary) is the pinned one
  (package-lock.json and scripts/javascript_env.py pin it for the repository; nothing pins it at run time).

What this branch does (h-minter minter.ts):
- Refuses to start when NODE_OPTIONS is set and non-empty (exit 2). The suite and the scripts start the issuer with
  their own environment; the light runs here (env -i) start normally.
- Writes one JSON line to STDERR at start: `issuerIdentityInfo` = resolved path and SHA-256 of bignumber.js as
  resolved from minter.ts AND as resolved from the core module's directory, the Node version, NODE_PATH. It goes to
  stderr, not the ready line, because tests/refund-finality/suite.ts:113 pins the exact key set of the ready line
  (a new field there fails the row "code that loads the issuer module gets no key ..."). This is DETECTION
  information for an operator, not prevention: in the red-team run it shows the shim path and a different digest.
- Does NOT change the checker id (owner decision).

Option to bind the dependencies into the id (owner decision; NOT done):
- Add to the canon object: sha256 of the resolved bignumber.js file (both resolutions; refuse to start if they
  differ), sha256 of the generated core JavaScript without footer, `process.version`, and the tsx loader file.
- Cost: every Node or bignumber.js update changes the id, so the sink pin and the Slice 1 records change; the suite
  and scripts/exit_slice1.py compute the id from three files today and must compute it the same way (a change to
  encoding.ts checkerSha256Of, owned by another worker, and to the suite). It closes the shim class only together with
  CLOSED-LAUNCH: an attacker who controls the launch can also replace Node.
