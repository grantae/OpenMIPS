#include <stdlib.h>
#include <string.h>
#include "endian.h"
#include "sha.h"

static const int32 k[] = {
  0x5a827999, //  0 <= t <= 19
  0x6ed9eba1, // 20 <= t <= 39
  0x8f1bbcdc, // 40 <= t <= 59
  0xca62c1d6  // 60 <= t <= 79
};

// ch is functions 0 - 19
uint32 ch(uint32 x, uint32 y, uint32 z) {
  return (x & y) ^ (~x & z);
}

// parity is functions 20 - 39 & 60 - 79
uint32 parity(uint32 x, uint32 y, uint32 z) {
  return x ^ y ^ z;
}

// maj is functions 40 - 59
uint32 maj(uint32 x, uint32 y, uint32 z) {
  return (x & y) ^ (x & z) ^ (y & z);
}

uint32 rotr(uint32 x, uint32 n) {
  return (x >> n) | ((x) << (32 - n));
}

uint32 shr(uint32 x, uint32 n) {
  return x >> n;
}

uint32 sigma_rot(uint32 x, int32 i) {
  return rotr(x, i ? 6 : 2) ^ rotr(x, i ? 11 : 13) ^ rotr(x, i ? 25 : 22);
}

uint32 sigma_shr(uint32 x, int32 i) {
  return rotr(x, i ? 17 : 7) ^ rotr(x, i ? 19 : 18) ^ shr(x, i ? 10 : 3);
}

void sha1_block_operate(const uint8 *block, uint32 hash[SHA1_RESULT_SIZE]) {
  uint32 W[80];
  uint32 t = 0;
  uint32 a, b, c, d, e, T;

  // First 16 blocks of W are the original 16 blocks of the input
  for (t = 0; t < 80; t++) {
    if (t < 16) {
      W[t] = (block[(t * 4)] << 24) |
             (block[(t * 4) + 1] << 16) |
             (block[(t * 4) + 2] << 8) |
             (block[(t * 4) + 3]);
    } else {
      W[t] = W[t - 3] ^
             W[t - 8] ^
             W[t - 14] ^
             W[t - 16];
      // Rotate left operation, simulated in C
      W[t] = (W[t] << 1) | ((W[t] & 0x80000000) >> 31);
    }
  }

  hash[0] = be2n_s32(hash[0]);
  hash[1] = be2n_s32(hash[1]);
  hash[2] = be2n_s32(hash[2]);
  hash[3] = be2n_s32(hash[3]);
  hash[4] = be2n_s32(hash[4]);

  a = hash[0];
  b = hash[1];
  c = hash[2];
  d = hash[3];
  e = hash[4];

  for (t = 0; t < 80; t++) {
    T = ((a << 5) | (a >> 27)) + e + k[(t / 20)] + W[t];

    if (t <= 19) {
      T += ch(b, c, d);
    } else if (t <= 39) {
      T += parity(b, c, d);
    } else if (t <= 59) {
      T += maj(b, c, d);
    } else {
      T += parity(b, c, d);
    }

    e = d;
    d = c;
    c = ((b << 30) | (b >> 2));
    b = a;
    a = T;
  }

  hash[0] += a;
  hash[1] += b;
  hash[2] += c;
  hash[3] += d;
  hash[4] += e;

  hash[0] = n2be_s32(hash[0]);
  hash[1] = n2be_s32(hash[1]);
  hash[2] = n2be_s32(hash[2]);
  hash[3] = n2be_s32(hash[3]);
  hash[4] = n2be_s32(hash[4]);
}

static const uint32 sha256_initial_hash[] = {
  0x67e6096a,
  0x85ae67bb,
  0x72f36e3c,
  0x3af54fa5,
  0x7f520e51,
  0x8c68059b,
  0xabd9831f,
  0x19cde05b
};

void sha256_block_operate(const uint8 *block, uint32 hash[8]) {
  uint32 W[64];
  uint32 a, b, c, d, e, f, g, h;
  uint32 T1, T2;
  int32 t, i;

  /**
   * The first 32 bits of the fractional parts of the cube roots
   * of the first sixty-four prime numbers.
   */
  static const uint32 k[] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  };

  // deal with little-endian-ness
  for (i = 0; i < 8; i++) {
    hash[i] = be2n_s32(hash[i]);
  }

  for (t = 0; t < 64; t++) {
    if (t <= 15) {
      W[t] = (block[(t * 4)] << 24) |
               (block[(t * 4) + 1] << 16) |
               (block[(t * 4) + 2] << 8) |
               (block[(t * 4) + 3]);
    } else {
      W[t] = sigma_shr(W[t - 2], 1) +
               W[t - 7] +
               sigma_shr(W[t - 15], 0) +
               W[t - 16];
    }
  }

  a = hash[0];
  b = hash[1];
  c = hash[2];
  d = hash[3];
  e = hash[4];
  f = hash[5];
  g = hash[6];
  h = hash[7];

  for (t = 0; t < 64; t++) {
    T1 = h + sigma_rot(e, 1) + ch(e, f, g) + k[t] + W[t];
    T2 = sigma_rot(a, 0) + maj(a, b, c);
    h = g;
    g = f;
    f = e;
    e = d + T1;
    d = c;
    c = b;
    b = a;
    a = T1 + T2;
  }

  hash[0] = a + hash[0];
  hash[1] = b + hash[1];
  hash[2] = c + hash[2];
  hash[3] = d + hash[3];
  hash[4] = e + hash[4];
  hash[5] = f + hash[5];
  hash[6] = g + hash[6];
  hash[7] = h + hash[7];

  // deal with little-endian-ness
  for (i = 0; i < 8; i++) {
    hash[i] = n2be_s32(hash[i]);
  }
}

#define SHA1_INPUT_BLOCK_SIZE 56
#define SHA1_BLOCK_SIZE 64

uint32 sha1_initial_hash[] = {
  0x01234567,
  0x89abcdef,
  0xfedcba98,
  0x76543210,
  0xf0e1d2c3
};

int32 sha1_hash(uint8 *input, int32 len, uint32 hash[SHA1_RESULT_SIZE]) {
  uint8 padded_block[SHA1_BLOCK_SIZE];
  int32 length_in_bits = len * 8;

  hash[0] = sha1_initial_hash[0];
  hash[1] = sha1_initial_hash[1];
  hash[2] = sha1_initial_hash[2];
  hash[3] = sha1_initial_hash[3];
  hash[4] = sha1_initial_hash[4];

  while (len >= SHA1_INPUT_BLOCK_SIZE) {
    if (len < SHA1_BLOCK_SIZE) {
      memset(padded_block, 0, sizeof(padded_block));
      memcpy(padded_block, input, len);
      padded_block[len] = 0x80;
      sha1_block_operate(padded_block, hash);
      input += len;
      len = -1;
    } else {
      sha1_block_operate(input, hash);
      input += SHA1_BLOCK_SIZE;
      len -= SHA1_BLOCK_SIZE;
    }
  }

  memset(padded_block, 0, sizeof(padded_block));
  if (len >= 0) {
    memcpy(padded_block, input, len);
    padded_block[len] = 0x80;
  }

  padded_block[SHA1_BLOCK_SIZE - 4] = (length_in_bits & 0xFF000000) >> 24;
  padded_block[SHA1_BLOCK_SIZE - 3] = (length_in_bits & 0x00FF0000) >> 16;
  padded_block[SHA1_BLOCK_SIZE - 2] = (length_in_bits & 0x0000FF00) >> 8;
  padded_block[SHA1_BLOCK_SIZE - 1] = (length_in_bits & 0x000000FF);

  sha1_block_operate(padded_block, hash);

  return 0;
}

void sha1_finalize(uint8 *padded_block, int32 length_in_bits) {
  padded_block[SHA1_BLOCK_SIZE - 4] = (length_in_bits & 0xFF000000) >> 24;
  padded_block[SHA1_BLOCK_SIZE - 3] = (length_in_bits & 0x00FF0000) >> 16;
  padded_block[SHA1_BLOCK_SIZE - 2] = (length_in_bits & 0x0000FF00) >> 8;
  padded_block[SHA1_BLOCK_SIZE - 1] = (length_in_bits & 0x000000FF);
}

void new_sha1_digest(digest_ctx *context) {
  context->hash_len = 5;
  context->input_len = 0;
  context->block_len = 0;
  context->hash = (uint32 *)
  malloc(context->hash_len * sizeof(uint32));
  memcpy(context->hash, sha1_initial_hash,
  context->hash_len * sizeof(uint32));
  memset(context->block, '\0', DIGEST_BLOCK_SIZE);
  context->block_operate = sha1_block_operate;
  context->block_finalize = sha1_finalize;
}

void new_sha256_digest(digest_ctx *context) {
  context->hash_len = 8;
  context->input_len = 0;
  context->block_len = 0;
  context->hash = (uint32 *) malloc(context->hash_len *
    sizeof(uint32));
  memcpy(context->hash, sha256_initial_hash, context->hash_len *
    sizeof(uint32));
  memset(context->block, '\0', DIGEST_BLOCK_SIZE);
  context->block_operate = sha256_block_operate;
  context->block_finalize = sha1_finalize;
}
