# Only this live trusted gate process can authorize reuse. Disk records, hashes
# beside them, and restored artifacts never create an authority entry. This is
# local execution provenance, NOT a signature or cross-run admission mechanism.
_PRODUCER_PID = os.getpid()
_PENDING_RECEIPTS = {}
_TRUSTED_RECEIPTS = {}


def receipt_slot(cache, key):
    if os.getpid() != _PRODUCER_PID or cache.is_symlink():
        raise Rejected('CACHE_PRODUCER: reuse requires the original trusted process')
    return (str(cache.resolve()), key)


def output_files(tree, work):
    # Reuse the existing provenance file inventory: exact membership, all bytes,
    # and no symlinks. Include checker bundles, TRX, reports, logs and generated
    # artifacts, not just the two digest fields in an operational receipt.
    try:
        return {'tree_build': provenance_files(tree / 'build'),
                'command_logs': provenance_files(work)}
    except (OSError, ProvenanceRejected) as error:
        raise Rejected('CACHE_ARTIFACT_INTEGRITY: ' + str(error)) from error


def reused_receipt(name, key, tree, trusted_root, verified, cache):
    path = cache / (key + '.json')
    slot = receipt_slot(cache, key)
    anchor = _TRUSTED_RECEIPTS.get(slot)
    if not path.exists() and not path.is_symlink():
        if anchor is not None:
            raise Rejected('CACHE_RECEIPT_MISSING: ' + name)
        return None
    if anchor is None:
        raise Rejected('CACHE_UNAUTHENTICATED: ' + name)
    try:
        raw = path.read_bytes()
        if path.is_symlink() or raw != anchor['receipt']:
            raise Rejected('CACHE_RECEIPT_INTEGRITY: ' + name)
        if output_files(anchor['tree'], anchor['work']) != anchor['files']:
            raise Rejected('CACHE_ARTIFACT_INTEGRITY: ' + name)
        previous = json.loads(raw)
        if (previous['obligation'] != name or previous['result'] != 'established'
                or previous['cache_key'] != key or previous['reused'] is not False
                or binding_violations(name, tree, trusted_root, verified)):
            raise Rejected('CACHE_IDENTITY: ' + name)
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise Rejected('CACHE_RECEIPT_INTEGRITY: ' + name) from error
    return dict(previous, reused=True, reuse_provenance={
        'scope': 'same_trusted_process', 'cross_run_authenticated': False,
        'receipt_sha256': digest(raw), 'files_sha256': digest(canonical(anchor['files']))})


def remember_fresh(records, cache, tree, work):
    # Called only on results returned by the actual trusted run_one dispatcher.
    # These remain pending until the caller checks the complete tree and coverage.
    fresh = [r for r in records.values() if r.get('result') == 'established'
             and r.get('reused') is False and r.get('cache_key')]
    if not fresh:
        return
    present = output_files(tree, work)
    for record in fresh:
        _PENDING_RECEIPTS[receipt_slot(cache, record['cache_key'])] = {
            'receipt': canonical(record), 'tree': tree, 'work': work, 'files': present}

