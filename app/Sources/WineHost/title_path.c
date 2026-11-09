/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * title_path — see include/title_path.h.
 *
 * Plain POSIX C with no Apple headers, so the host C tests (`pp test`, app/tests)
 * can build and exercise it on the Linux host.
 */

#include "title_path.h"

#include <dirent.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>

/* Wine's RTL_USER_PROCESS_PARAMETERS keeps the current directory in a
 * MAX_PATH-character buffer (ntdll env.c build_initial_params), with a
 * trailing backslash, so the working directory must fit in 259 characters. */
#define DOS_MAX_PATH 260

static int fail(char *msg, size_t msglen, int rc, const char *fmt, ...) __attribute__((format(printf, 4, 5)));
static int fail(char *msg, size_t msglen, int rc, const char *fmt, ...)
{
    if (msg && msglen) {
        va_list ap;
        va_start(ap, fmt);
        vsnprintf(msg, msglen, fmt, ap);
        va_end(ap);
    }
    return rc;
}

/* The length of UTF-8 s in UTF-16 units (a character past U+FFFF takes two),
 * which is what Windows' MAX_PATH counts; -1 when s is not well-formed UTF-8. */
static long utf16_length(const char *s)
{
    long n = 0;
    const unsigned char *p = (const unsigned char *)s;
    while (*p) {
        unsigned c = *p, len, min;
        if (c < 0x80) { n++; p++; continue; }
        if ((c & 0xe0) == 0xc0) { len = 2; min = 0x80; c &= 0x1f; }
        else if ((c & 0xf0) == 0xe0) { len = 3; min = 0x800; c &= 0x0f; }
        else if ((c & 0xf8) == 0xf0) { len = 4; min = 0x10000; c &= 0x07; }
        else return -1;
        for (unsigned i = 1; i < len; i++) {
            if ((p[i] & 0xc0) != 0x80) return -1;
            c = (c << 6) | (p[i] & 0x3f);
        }
        if (c < min || c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) return -1;
        n += c >= 0x10000 ? 2 : 1;
        p += len;
    }
    return n;
}

static int is_sep(char c)
{
    return c == '\\' || c == '/';
}

/* A name component Windows would accept and name exactly as written. */
static const char *bad_component(const char *c, size_t n)
{
    if (!n) return "an empty component";
    if ((n == 1 && c[0] == '.') || (n == 2 && c[0] == '.' && c[1] == '.')) return "a '.' or '..' component";
    if (c[n - 1] == '.' || c[n - 1] == ' ') return "a component ending in '.' or ' ' (Windows drops them)";
    for (size_t i = 0; i < n; i++) {
        unsigned char u = (unsigned char)c[i];
        if (u < 0x20 || strchr("<>:\"|?*", u)) return "a character Windows forbids in a name";
    }
    return NULL;
}

/* The entry of dir named name: exact if present, otherwise the one ASCII
 * case-insensitive match. 0 found (on-disk name in hit), -2 none, -1 ambiguous. */
static int find_entry(const char *dir, const char *name, char *hit, size_t hitlen)
{
    char p[2048 + 256 + 2];   /* the resolver's host path and a component */
    struct stat st;
    snprintf(p, sizeof(p), "%s/%s", dir, name);
    if (lstat(p, &st) == 0) {
        snprintf(hit, hitlen, "%s", name);
        return 0;
    }
    DIR *d = opendir(dir);
    if (!d) return -2;
    int found = 0;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (strcasecmp(e->d_name, name)) continue;
        if (found++) break;
        snprintf(hit, hitlen, "%s", e->d_name);
    }
    closedir(d);
    return found == 1 ? 0 : found ? -1 : -2;
}

int title_path_resolve(const char *prefix_dir, const char *path, title_path *out, char *msg, size_t msglen)
{
    if (msg && msglen) msg[0] = 0;
    if (!prefix_dir || !*prefix_dir || !path || !out) return fail(msg, msglen, -1, "no prefix or no path");
    memset(out, 0, sizeof(*out));

    const char *s = path;
    /* UTF-8, which the session root turns into UTF-16 (MultiByteToWideChar with
     * MB_ERR_INVALID_CHARS refuses anything else); a Japanese folder name is fine. */
    if (utf16_length(s) < 0) return fail(msg, msglen, -1, "'%s': not valid UTF-8", path);
    if (((s[0] | 0x20) >= 'a' && (s[0] | 0x20) <= 'z') && s[1] == ':') {
        if ((s[0] | 0x20) != 'c')
            return fail(msg, msglen, -1, "'%s': drive %c: is not in the prefix; only C: maps to drive_c", path, s[0]);
        if (!is_sep(s[2])) return fail(msg, msglen, -1, "'%s': a drive-relative path has no fixed directory", path);
        s += 3;
    } else if (is_sep(s[0])) {
        if (is_sep(s[1])) return fail(msg, msglen, -1, "'%s': UNC and device paths are not in the prefix", path);
        s += 1;
    }
    if (!*s) return fail(msg, msglen, -1, "'%s': names no file", path);

    char cur[2048];
    int n = snprintf(cur, sizeof(cur), "%s/drive_c", prefix_dir);
    size_t dos_len = (size_t)snprintf(out->dos, sizeof(out->dos), "C:");
    size_t dir_end = 0;   /* length of out->dos up to the last separator */
    if (n < 0 || (size_t)n >= sizeof(cur)) return fail(msg, msglen, -4, "prefix path too long");

    while (*s) {
        const char *c = s;
        while (*s && !is_sep(*s)) s++;
        size_t len = (size_t)(s - c);
        int last = !*s;
        if (!last) {
            s++;
            if (!*s) return fail(msg, msglen, -1, "'%s' ends in a separator; it names a directory", path);
        }
        const char *why = bad_component(c, len);
        if (why) return fail(msg, msglen, -1, "'%s': %s", path, why);

        char name[256], hit[256];
        if (len >= sizeof(name)) return fail(msg, msglen, -4, "'%s': a component is too long", path);
        memcpy(name, c, len);
        name[len] = 0;
        int rc = find_entry(cur, name, hit, sizeof(hit));
        if (rc == -1) return fail(msg, msglen, -1, "'%s': '%s' matches more than one name in %s", path, name, cur);
        if (rc) return fail(msg, msglen, -2, "'%s': no '%s' in %s", path, name, cur);

        size_t cl = strlen(cur);
        n = snprintf(cur + cl, sizeof(cur) - cl, "/%s", hit);
        if (n < 0 || (size_t)n >= sizeof(cur) - cl) return fail(msg, msglen, -4, "'%s': host path too long", path);
        dir_end = dos_len;
        n = snprintf(out->dos + dos_len, sizeof(out->dos) - dos_len, "\\%s", hit);
        if (n < 0 || (size_t)n >= sizeof(out->dos) - dos_len) return fail(msg, msglen, -4, "'%s': too long", path);
        dos_len += (size_t)n;

        struct stat st;
        if (stat(cur, &st)) return fail(msg, msglen, -2, "'%s': %s is a dangling link", path, cur);
        if (!last && !S_ISDIR(st.st_mode)) return fail(msg, msglen, -2, "'%s': %s is not a directory", path, cur);
        if (last && !S_ISREG(st.st_mode)) return fail(msg, msglen, -3, "'%s': %s is not a regular file", path, cur);
    }

    if (dir_end == 2) snprintf(out->dos_dir, sizeof(out->dos_dir), "C:\\");
    else snprintf(out->dos_dir, sizeof(out->dos_dir), "%.*s", (int)dir_end, out->dos);
    if (utf16_length(out->dos) >= DOS_MAX_PATH || utf16_length(out->dos_dir) + 1 >= DOS_MAX_PATH)
        return fail(msg, msglen, -4, "'%s': longer than MAX_PATH as a DOS path", path);
    snprintf(out->unix_path, sizeof(out->unix_path), "%s", cur);
    return fail(msg, msglen, 0, "%s (working directory %s)", out->dos, out->dos_dir);
}
