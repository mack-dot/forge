# Independent-copy verification — pending location

The owner reports a backup on another device. Its device/folder is still unknown
to this session. No remote connection, copy validation or remote restore ran.
Only Macintosh HD and Recovery are mounted on this Mac. This does not disprove
the reported independent copy. Local Git fsck/bundle verification and local
archive validation are separate completed checks.

The independent device must contain both original archives and external manifests:

- Raw archive SHA256 e2491743d39ee0fad290c34c558b3f147e4a72125e72171615cee49674f2986b.
- Raw manifest SHA256 d2f6313b583ba77e1f6c44f29566ac258d44d6d62137e9f62ae2ff73aed204f8.
- Sanitized archive SHA256 ac84dd27cfe9b7a57f1eb085fd37d06df787d7dddc7f9b94fe52c06c92996570.
- Sanitized manifest SHA256 f4a8651e992778eba621d7b2214abde6a94945323ca080d25c3ddba91c281c77.

Copy the existing `results/ops-readiness/integration-2026-11-02/check_archives.py`
and this packet's `restore_existing_backup.py` beside each other on that device.
Preserve the original archives. Select a new private restore directory.
Run there, replacing the two absolute paths with the actual locations:

```sh
python3 -B restore_existing_backup.py --archives /absolute/existing/archive-folder --restore /absolute/new/private-restore
```

The script first uses the unchanged archive/member checker, then restores only
regular safe paths without overwriting anything. It reads every restored member
and compares its hash/length. Keep any failed attempt and inspect its error.
Return only `restore-result.json` and the command's actual exit, not raw contents.
Record the device/storage failure domain separately: a reported hostname or
matching hashes alone do not establish physical independence.

This restore command is NOT RUN. The original10160-file text archives exclude
large files, the full external proof pool and subsequent records. The older
local Git bundle also predates the newest commits. Confirm preservation of the
new replay/observation packet separately. Do not label the old copy a complete
backup of this session without checking its contents.
