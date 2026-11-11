# Published runtime boundary

The pinned local CakeML sources are the exact technical reference for this
artifact. `source-inspection.json` binds nine unchanged files to commit
`cd9155694c16831373ab695a670794f23282ed62`. The original files and snapshots match.

The CakeML authors describe C FFI implementations as external to the verified
compiler. Their account includes C wrappers, linking, OS loading/I/O, and the
machine/FFI models in the trusted base. This supports an explicit trust boundary;
it does not supply a proof for this Clang object or Darwin process.
[Program Verification in the Presence of I/O, pages 2–5](https://cakeml.org/vstte18.pdf).

Apple documents a negative return and errno on read failure. Its archived page
lists EAGAIN for nonblocking reads without available data, EBADF for an unsuitable
descriptor, and EINTR before data arrives. These documented cases explain why a
readable descriptor alone is not a sufficient physical premise. The archive is
not a formal semantics or a verification of the current Darwin kernel.
[Apple read(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/read.2.html).

The Open Group POSIX read page at
https://pubs.opengroup.org/onlinepubs/9799919799/functions/read.html returned HTTP
403 during this run. No claim relies on its unavailable contents. No alternate
access was attempted.

The pinned fsFFI source itself warns that its unchanged-position error model is
inaccurate for an unspecified physical file position after error. Its IO_fs
record has no nonblocking flag, errno, or signal state. Its numchars stream models
read/write capacity; it does not by itself model these OS errors.

A search of the available local toolchain found no existing checked translation
of this C runtime object through AutoCorres, CompCert, Cerberus, or a comparable
C verification chain. This is an availability finding, not a claim that such
infrastructure cannot exist elsewhere. CakeML's Pancake infrastructure targets
its own source language; it does not establish correctness of this existing
Clang-produced object. No runtime, model, compiler, or executable was replaced.
