/* Test-only dyld interposer for the forge-airlock engine (Goal 20). NOT part of the engine. NOT in the trusted base.
 * scripts/exit_goal20_sdk.py builds it with /usr/bin/cc -dynamiclib. tests/airlock/test_engine.py (cases trace and
 * dispatch) loads it into the engine process with DYLD_INSERT_LIBRARIES. The engine starts its helper processes with
 * an empty environment, so the interposer never reaches the refund binary or Node.
 *
 * Why not tests/silicon_sink/interpose.c: that file traces and fails writes only for files named ledger.*. The engine
 * names its files airlock.wal, airlock.epoch and policy-<name>.json. This file is the same design with other names.
 *
 *   AIRLOCK_TRACE=<file>          one line per call: "flock <name>", "read <name>", "write <name> <length>",
 *                                 "fullfsync <name> <result>", "ftruncate <name> <length>", "close <name>",
 *                                 "rename <from> <to>". read, write, ftruncate and close only for store files and
 *                                 stdout; fullfsync and flock for every descriptor (a folder too).
 *   AIRLOCK_FAIL_SYNC=<k>         the k-th fcntl(F_FULLFSYNC) of the process fails with EIO (the real call is not made)
 *   AIRLOCK_FAIL_SYNC_FROM=<k>    the k-th and every later fcntl(F_FULLFSYNC) fail with EIO
 *   AIRLOCK_FAIL_WRITE=<k>        the k-th write to a store file fails with ENOSPC (nothing is written)
 *   AIRLOCK_SHORT_WRITE=<n>       with AIRLOCK_FAIL_WRITE: that write really writes its first n bytes and returns n;
 *                                 the NEXT write to a store file then fails with ENOSPC (a short write on a full disk)
 *   <name> is the last path component of the file, or "stdout" for descriptor 1. A store file is a file whose name
 *   starts with "airlock." or "policy-".
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

static int store_file(const char *name) {
    return strncmp(name, "airlock.", 8) == 0 || strncmp(name, "policy-", 7) == 0;
}

static void note(const char *line) {
    const char *file = getenv("AIRLOCK_TRACE");
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
    const char *from = getenv("AIRLOCK_FAIL_SYNC_FROM");
    int fail = chosen("AIRLOCK_FAIL_SYNC", &syncs) || (from && syncs >= atoi(from));
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
    int store = store_file(name);
    if (!store && fd != 1) return write(fd, buffer, length);
    int failing = store && (disk_full || chosen("AIRLOCK_FAIL_WRITE", &writes));
    const char *part = getenv("AIRLOCK_SHORT_WRITE");
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

static ssize_t traced_read(int fd, void *buffer, size_t length) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    if (store_file(name)) {
        snprintf(line, sizeof line, "read %s\n", name);
        note(line);
    }
    return read(fd, buffer, length);
}

static int traced_flock(int fd, int operation) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    snprintf(line, sizeof line, "flock %s %d\n", name, operation);
    note(line);
    return flock(fd, operation);
}

static int traced_ftruncate(int fd, off_t length) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    if (store_file(name)) {
        snprintf(line, sizeof line, "ftruncate %s %lld\n", name, (long long)length);
        note(line);
    }
    return ftruncate(fd, length);
}

static int traced_close(int fd) {
    char name[256], line[320];
    name_of(fd, name, sizeof name);
    if (store_file(name)) {
        snprintf(line, sizeof line, "close %s\n", name);
        note(line);
    }
    return close(fd);
}

static int traced_rename(const char *from, const char *to) {
    char line[2 * MAXPATHLEN + 16];
    const char *a = strrchr(from, '/'), *b = strrchr(to, '/');
    snprintf(line, sizeof line, "rename %s %s\n", a ? a + 1 : from, b ? b + 1 : to);
    note(line);
    return rename(from, to);
}

#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *r; const void *o; } interpose_##original \
        __attribute__((section("__DATA,__interpose"))) = { (const void *)replacement, (const void *)original }
INTERPOSE(traced_fcntl, fcntl);
INTERPOSE(traced_write, write);
INTERPOSE(traced_read, read);
INTERPOSE(traced_flock, flock);
INTERPOSE(traced_ftruncate, ftruncate);
INTERPOSE(traced_close, close);
INTERPOSE(traced_rename, rename);
