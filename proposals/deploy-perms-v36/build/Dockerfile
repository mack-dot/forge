FROM ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a9f4b0dd59d7c8d30727d36e039bfe72a2a9f9c4a99c68e413037e902
# Create the directory first: COPY --chmod would give a new parent directory
# the file's mode 0444, which has no search bit for UID 1000.
WORKDIR /opt/forge
COPY --chown=1000:1000 --chmod=0444 gcd-selftest.elf /opt/forge/gcd-selftest.elf
USER 1000:1000
ENTRYPOINT ["python3", "-c", "import signal; signal.pause()"]
