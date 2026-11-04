# Fixed-ELF runtime replay

Authenticate the archive digest against the independent review packet first.
The local manifest cannot authenticate itself. No signing/admission is performed.
Use the exact existing checker Docker image named in commands.json; it must
already be present. No network, package install or persistent service is added.

Run `python3 -B replay.py --out /absolute/new/runtime-output`.
The original producer checker verifies Ubuntu signatures, signed indices and
all13 observer packages. It compares the complete413-member observer tree.
The unchanged observer then runs the held ELF with the pinned QEMU/GDB tools,
reads the LOAD bytes and records actual guest/parent exits. Finally it checks
observer identity again. Each container retains the original resource limits.

All host input paths are relative to this packet. The QEMU binary and ELF have
the separately held expected digests. QEMU's historical distribution-authentication
records are referenced in the parent assurance report; this replay executes the
GDB producer chain, not a new QEMU package/source rebuild. Its held QEMU digest
must be approved through the external packet anchor.

The image, Docker/VM/host and translation layers remain trust boundaries.
A different host may yield a different SP/register trace. Such a difference
must be reported and checked before this recorded-entry theorem can apply.
Passing this observer does not automatically check all21 frames against Rocq.
Use the separate exact trace binding and proof replay described in the report.
