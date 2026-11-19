/* Test-only dyld interposer for the native silicon sink (goal 19). NOT part of the sink. NOT in the trusted base.
 * scripts/exit_silicon_sink.py builds it with /usr/bin/cc -dynamiclib. A test loads it with DYLD_INSERT_LIBRARIES.
 *
 * Role 1, inside the sink process: record the order of the system calls that matter, and inject faults.
 *   SINK_TRACE=<file>        one line per call: "flock <name>", "write <name> <length>", "fullfsync <name> <result>",
 *                            "ftruncate <name> <length>", "close <name>" (close and ftruncate only for files named ledger.*)
 *   SINK_FAIL_SYNC=<k>       the k-th fcntl(F_FULLFSYNC) of the process fails with EIO (the real call is not made)
 *   SINK_FAIL_SYNC_FROM=<k>  the k-th and every later fcntl(F_FULLFSYNC) fail with EIO
 *   SINK_FAIL_WRITE=<k>      the k-th write to a file named ledger.* fails with ENOSPC (nothing is written)
 *   SINK_SHORT_WRITE=<n>     with SINK_FAIL_WRITE: that write really writes its first n bytes and returns n; the NEXT write
 *                            to a ledger file then fails with ENOSPC (a short write on a full disk)
 *   <name> is the last path component of the file, or "stdout" for descriptor 1.
 *
 * Role 2, inside a process named "refund" (the CakeML binary) and only if SINK_FORGE is set: write the accept
 *   frame for whatever request arrives and exit 0. The sink starts the binary with an empty environment, so this
 *   role must never run through the sink. The test first shows that the forgery works when the variable does
 *   reach the binary.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/param.h>
#include <unistd.h>

static void name_of(int fd, char *out, size_t size) {
    char path[MAXPATHLEN];
    if (fd == 1) {
        snprintf(out, size, "stdout");
    } else if (fcntl(fd, F_GETPATH, path) == 0) {
        const char *slash = strrchr(path, '/');
        snprintf(out, size, "%s", slash ? slash + 1 : path);
    } else {
        snprintf(out, size, "fd%d", fd);
    }
}

static void note(const char *line) {
    const char *file = getenv("SINK_TRACE");
    if (!file) return;
    int fd = open(file, O_WRONLY | O_APPEND | O_CREAT, 0600);
    if (fd < 0) return;
    (void)!write(fd, line, strlen(line));
    close(fd);
}

static int chosen(const char *variable, int *counter) {
    const char *value = getenv(variable);
    *counter += 1;
    return value && atoi(value) == *counter;
}

static int traced_fcntl(int fd, int cmd, ...) {
    static int syncs = 0;
    va_list ap;
    va_start(ap, cmd);
    void *arg = va_arg(ap, void *);
    va_end(ap);
    if (cmd != F_FULLFSYNC) return fcntl(fd, cmd, arg);
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    const char *from = getenv("SINK_FAIL_SYNC_FROM");
    int fail = chosen("SINK_FAIL_SYNC", &syncs) || (from && syncs >= atoi(from));
    int result = fail ? -1 : fcntl(fd, cmd, arg);
    int saved = fail ? EIO : errno;
    snprintf(line, sizeof line, "fullfsync %s %d\n", name, result);
    note(line);
    errno = saved;
    return result;
}

static ssize_t traced_write(int fd, const void *buffer, size_t length) {
    static int writes = 0, disk_full = 0;
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    int ledger = strncmp(name, "ledger.", 7) == 0;
    if (!ledger && fd != 1) return write(fd, buffer, length);
    int failing = ledger && (disk_full || chosen("SINK_FAIL_WRITE", &writes));
    const char *part = getenv("SINK_SHORT_WRITE");
    if (failing && !disk_full && part && (size_t)atoi(part) < length) {
        disk_full = 1;
        snprintf(line, sizeof line, "write %s %d SHORT\n", name, atoi(part));
        note(line);
        return write(fd, buffer, (size_t)atoi(part));
    }
    if (failing) {
        disk_full = 0;
        snprintf(line, sizeof line, "write %s %zu FAILED\n", name, length);
        note(line);
        errno = ENOSPC;
        return -1;
    }
    snprintf(line, sizeof line, "write %s %zu\n", name, length);
    note(line);
    return write(fd, buffer, length);
}

static int traced_flock(int fd, int operation) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    snprintf(line, sizeof line, "flock %s\n", name);
    note(line);
    return flock(fd, operation);
}

static int traced_ftruncate(int fd, off_t length) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    if (strncmp(name, "ledger.", 7) == 0) {
        snprintf(line, sizeof line, "ftruncate %s %lld\n", name, (long long)length);
        note(line);
    }
    return ftruncate(fd, length);
}

static int traced_close(int fd) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    if (strncmp(name, "ledger.", 7) == 0) {
        snprintf(line, sizeof line, "close %s\n", name);
        note(line);
    }
    return close(fd);
}

#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *r; const void *o; } interpose_##original \
        __attribute__((section("__DATA,__interpose"))) = { (const void *)replacement, (const void *)original }
INTERPOSE(traced_fcntl, fcntl);
INTERPOSE(traced_write, write);
INTERPOSE(traced_flock, flock);
INTERPOSE(traced_ftruncate, ftruncate);
INTERPOSE(traced_close, close);

__attribute__((constructor)) static void forge(void) {
    if (!getenv("SINK_FORGE") || strcmp(getprogname(), "refund") != 0) return;
    char in[1024], *field[9];
    ssize_t total = 0, got;
    while (total < (ssize_t)sizeof in - 1 && (got = read(0, in + total, sizeof in - 1 - total)) > 0) total += got;
    in[total] = 0;
    int count = 0;
    for (char *token = strtok(in, " ()"); token && count < 9; token = strtok(NULL, " ()")) field[count++] = token;
    if (count == 9) dprintf(1, "(refund-result-v1 True %s %s %s %s 1)", field[7], field[8], field[0], field[1]);
    _exit(0);
}
