// Guest context MACs on Android CPUs without pointer authentication. These signatures
// are local to this host process; they do not interoperate with hardware QARMA.
// SipHash-2-4, specialized to two 64-bit words. Based on the CC0 reference by
// Jean-Philippe Aumasson and Daniel J. Bernstein: https://github.com/veorq/SipHash.
#ifndef DM_PAUTH_H
#define DM_PAUTH_H
#include <stdint.h>
static inline uint64_t pauth_rot(uint64_t x, unsigned n) { return (x << n) | (x >> (64 - n)); }
static inline void pauth_round(uint64_t v[4]) {
    v[0] += v[1]; v[1] = pauth_rot(v[1], 13); v[1] ^= v[0]; v[0] = pauth_rot(v[0], 32);
    v[2] += v[3]; v[3] = pauth_rot(v[3], 16); v[3] ^= v[2];
    v[0] += v[3]; v[3] = pauth_rot(v[3], 21); v[3] ^= v[0];
    v[2] += v[1]; v[1] = pauth_rot(v[1], 17); v[1] ^= v[2]; v[2] = pauth_rot(v[2], 32);
}
static inline uint64_t pauth_hash(const uint64_t key[2], uint64_t a, uint64_t b) {
    uint64_t v[4] = {UINT64_C(0x736f6d6570736575) ^ key[0], UINT64_C(0x646f72616e646f6d) ^ key[1],
                     UINT64_C(0x6c7967656e657261) ^ key[0], UINT64_C(0x7465646279746573) ^ key[1]};
    uint64_t block[3] = {a, b, UINT64_C(16) << 56};
    for (int i = 0; i < 3; i++) { v[3] ^= block[i]; pauth_round(v); pauth_round(v); v[0] ^= block[i]; }
    v[2] ^= 0xff;
    for (int i = 0; i < 4; i++) pauth_round(v);
    return v[0] ^ v[1] ^ v[2] ^ v[3];
}
// entry.S saves the gate return point at regs[30]. The original guest FP/LR are
// in the two-word frame at regs[99], which the gate stub restores on return.
static inline uint64_t pauth_read(const uint64_t *r, unsigned n, int sp) {
    if (n < 29) return r[n];
    if (n < 31) return ((const uint64_t *)(uintptr_t)r[99])[n - 29];
    return sp ? r[99] + 16 : 0;
}
static inline void pauth_pacga(uint64_t *r, unsigned arg, const uint64_t key[2]) {
    unsigned d = arg & 31, n = (arg >> 5) & 31, m = (arg >> 10) & 31;
    uint64_t a = pauth_read(r, n, 0), b = pauth_read(r, m, 1);
    uint64_t result = pauth_hash(key, a, b) & UINT64_C(0xffffffff00000000);
    if (d < 29) r[d] = result;
    else if (d < 31) ((uint64_t *)(uintptr_t)r[99])[d - 29] = result;
}
#endif
