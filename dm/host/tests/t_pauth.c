#include "../pauth.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static unsigned arg(unsigned d, unsigned n, unsigned m) { return d | n << 5 | m << 10; }
int main(void) {
    const uint64_t key[2] = {UINT64_C(0x0706050403020100), UINT64_C(0x0f0e0d0c0b0a0908)};
    // Official SipHash-2-4 vector for bytes 00..0f under key 00..0f.
    assert(pauth_hash(key, key[0], key[1]) == UINT64_C(0x3f2acc7f57c29bdb));
    uint64_t r[100] = {0}, saved[2] = {0x1111, UINT64_C(0x8000000012340001)};
    r[99] = (uintptr_t)saved; r[30] = 0xfeed; r[0] = 0xabc; r[2] = UINT64_C(0x80300000dead0000);
    pauth_pacga(r, arg(2, 0, 2), key);
    pauth_pacga(r, arg(2, 30, 2), key); // aliases its modifier; uses original tagged LR, not gate return point
    uint64_t expected = pauth_hash(key, saved[1], pauth_hash(key, 0xabc, UINT64_C(0x80300000dead0000)) & UINT64_C(0xffffffff00000000)) & UINT64_C(0xffffffff00000000);
    assert(r[2] == expected && !(r[2] & UINT32_MAX));
    assert((pauth_hash(key, saved[1] ^ 1, pauth_hash(key, 0xabc, UINT64_C(0x80300000dead0000)) & UINT64_C(0xffffffff00000000)) & UINT64_C(0xffffffff00000000)) != expected);
    r[5] = 123; pauth_pacga(r, arg(6, 31, 31), key);
    assert(r[6] == (pauth_hash(key, 0, (uintptr_t)saved + 16) & UINT64_C(0xffffffff00000000)));
    pauth_pacga(r, arg(30, 5, 31), key);
    assert(saved[1] == (pauth_hash(key, 123, (uintptr_t)saved + 16) & UINT64_C(0xffffffff00000000)) && r[30] == 0xfeed);
    uint64_t before[100]; memcpy(before, r, sizeof r); pauth_pacga(r, arg(31, 0, 2), key);
    assert(!memcmp(before, r, sizeof r));
    puts("pauth: reference MAC, SDK context chain, tag tamper, LR/SP, aliasing and discard passed");
}
