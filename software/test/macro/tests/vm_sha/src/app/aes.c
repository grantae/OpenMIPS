#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "aes.h"

static void xor(uint8 *target, const uint8 *src, int len) {
  while (len--) {
    *target++ ^= *src++;
  }
}

static void rot_word(uint8 *w) {
  uint8 tmp;

  tmp = w[0];
  w[0] = w[1];
  w[1] = w[2];
  w[2] = w[3];
  w[3] = tmp;
}

static uint8 sbox[16][16] = {
  { 0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76 },
  { 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0 },
  { 0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15 },
  { 0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75 },
  { 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84 },
  { 0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf },
  { 0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8 },
  { 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2 },
  { 0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73 },
  { 0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb },
  { 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79 },
  { 0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08 },
  { 0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a },
  { 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e },
  { 0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf },
  { 0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16 },
};

static void sub_word(uint8 *w) {
  int i = 0;

  for (i = 0; i < 4; i++) {
    w[i] = sbox[(w[i] & 0xF0) >> 4][w[i] & 0x0F];
  }
}

static void compute_key_schedule(const uint8 *key, int key_length, uint8 w[][4]) {
  int i;
  int key_words = key_length >> 2;
  uint8 rcon = 0x01;

  // First, copy the key directly into the key schedule
  memcpy(w, key, key_length);
  for (i = key_words; i < 4 * (key_words + 7); i++) {
    memcpy(w[i], w[i-1], 4);
    if (!(i % key_words)) {
      rot_word(w[i]);
      sub_word(w[i]);
      if (!(i % 36)) {
        rcon = 0x1b;
      }
      w[i][0] ^= rcon;
      rcon <<= 1;
    } else if ((key_words > 6) && ((i % key_words) == 4)) {
      sub_word(w[i]);
    }
    w[i][0] ^= w[i - key_words][0];
    w[i][1] ^= w[i - key_words][1];
    w[i][2] ^= w[i - key_words][2];
    w[i][3] ^= w[i - key_words][3];
  }
}

static void add_round_key(uint8 state[][4], uint8 w[][4]) {
  int c, r;

  for (c = 0; c < 4; c++) {
    for (r = 0; r < 4; r++) {
      state[r][c] = state[r][c] ^ w[c][r];
    }
  }
}

static void sub_bytes(uint8 state[][4]) {
  int r, c;

  for (r = 0; r < 4; r++) {
    for (c = 0; c < 4; c++) {
      state[r][c] = sbox[(state[r][c] & 0xF0) >> 4][state[r][c] & 0x0F];
    }
  }
}

static void shift_rows(uint8 state[][4]) {
  int tmp;

  tmp = state[1][0];
  state[1][0] = state[1][1];
  state[1][1] = state[1][2];
  state[1][2] = state[1][3];
  state[1][3] = tmp;

  tmp = state[2][0];
  state[2][0] = state[2][2];
  state[2][2] = tmp;
  tmp = state[2][1];
  state[2][1] = state[2][3];
  state[2][3] = tmp;

  tmp = state[3][3];
  state[3][3] = state[3][2];
  state[3][2] = state[3][1];
  state[3][1] = state[3][0];
  state[3][0] = tmp;
}

uint8 xtime(uint8 x) {
  return (x << 1) ^ ((x & 0x80) ? 0x1b : 0x00);
}

uint8 dot(uint8 x, uint8 y) {
  uint8 mask;
  uint8 product = 0;

  for (mask = 0x01; mask; mask <<= 1) {
    if (y & mask) {
      product ^= x;
    }
    x = xtime(x);
  }
  return product;
}

static void mix_columns(uint8 s[][4]) {
  int c;
  uint8 t[4];

  for (c = 0; c < 4; c++) {
    t[0] = dot(2, s[0][c]) ^ dot(3, s[1][c]) ^ s[2][c] ^ s[3][c];
    t[1] = s[0][c] ^ dot(2, s[1][c]) ^ dot(3, s[2][c]) ^ s[3][c];
    t[2] = s[0][c] ^ s[1][c] ^ dot(2, s[2][c]) ^ dot(3, s[3] [c]);
    t[3] = dot(3, s[0][c]) ^ s[1][c] ^ s[2][c] ^ dot(2, s[3][c]);
    s[0][c] = t[0];
    s[1][c] = t[1];
    s[2][c] = t[2];
    s[3][c] = t[3];
  }
}

static void aes_block_encrypt(const uint8 *input_block, uint8 *output_block, const uint8 *key, int key_size) {
  int r, c;
  int round;
  int nr;
  uint8 state[4][4];
  uint8 w[60][4];

  for (r = 0; r < 4; r++) {
    for (c = 0; c < 4; c++) {
      state[r][c] = input_block[r + (4 * c)];
    }
  }
  // rounds = key size in 4-byte words + 6
  nr = (key_size >> 2) + 6;

  compute_key_schedule(key, key_size, w);

  add_round_key(state, &w[0]);

  for (round = 0; round < nr; round++) {
    sub_bytes(state);
    shift_rows(state);
    if (round < (nr - 1)) {
      mix_columns(state);
    }
    add_round_key(state, &w[(round + 1) * 4]);
  }

  for (r = 0; r < 4; r++) {
    for (c = 0; c < 4; c++) {
      output_block[r + (4 * c)] = state[r][c];
    }
  }
}

static void inv_shift_rows(uint8 state[][4]) {
  int tmp;

  tmp = state[1][2];
  state[1][2] = state[1][1];
  state[1][1] = state[1][0];
  state[1][0] = state[1][3];
  state[1][3] = tmp;

  tmp = state[2][0];
  state[2][0] = state[2][2];
  state[2][2] = tmp;
  tmp = state[2][1];
  state[2][1] = state[2][3];
  state[2][3] = tmp;

  tmp = state[3][0];
  state[3][0] = state[3][1];
  state[3][1] = state[3][2];
  state[3][2] = state[3][3];
  state[3][3] = tmp;
}

static uint8 inv_sbox[16][16] = {
  { 0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb },
  { 0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb },
  { 0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e },
  { 0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25 },
  { 0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92 },
  { 0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84 },
  { 0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06 },
  { 0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b },
  { 0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73 },
  { 0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e },
  { 0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b },
  { 0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4 },
  { 0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f },
  { 0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef },
  { 0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61 },
  { 0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d },
};

static void inv_sub_bytes(uint8 state[][4]) {
  int r, c;

  for (r = 0; r < 4; r++) {
    for (c = 0; c < 4; c++) {
      state[r][c] = inv_sbox[(state[r][c] & 0xF0) >> 4][state[r][c] & 0x0F];
    }
  }
}

static void inv_mix_columns(uint8 s[][4]) {
  int c;
  uint8 t[4];

  for (c = 0; c < 4; c++) {
    t[0] = dot(0x0e, s[0][c]) ^ dot(0x0b, s[1][c]) ^ dot(0x0d, s[2][c]) ^ dot(0x09, s[3][c]);
    t[1] = dot(0x09, s[0][c]) ^ dot(0x0e, s[1][c]) ^ dot(0x0b, s[2][c]) ^ dot(0x0d, s[3][c]);
    t[2] = dot(0x0d, s[0][c]) ^ dot(0x09, s[1][c]) ^ dot(0x0e, s[2][c]) ^ dot(0x0b, s[3][c]);
    t[3] = dot(0x0b, s[0][c]) ^ dot(0x0d, s[1][c]) ^ dot(0x09, s[2][c]) ^ dot(0x0e, s[3][c]);
    s[0][c] = t[0];
    s[1][c] = t[1];
    s[2][c] = t[2];
    s[3][c] = t[3];
  }
}

static void aes_block_decrypt(const uint8 *input_block, uint8 *output_block, const uint8 *key, int key_size) {
  int r, c;
  int round;
  int nr;
  uint8 state[4][4];
  uint8 w[60][4];

  for (r = 0; r < 4; r++) {
    for (c = 0; c < 4; c++) {
      state[r][c] = input_block[r + (4 * c)];
    }
  }
  // rounds = key size in 4-byte words + 6
  nr = (key_size >> 2) + 6;

  compute_key_schedule(key, key_size, w);

  add_round_key(state, &w[nr * 4]);

  for (round = nr; round > 0; round--) {
    inv_shift_rows(state);
    inv_sub_bytes(state);
    add_round_key(state, &w[(round - 1) * 4]);
    if (round > 1) {
      inv_mix_columns(state);
    }
  }

  for (r = 0; r < 4; r++) {
    for (c = 0; c < 4; c++) {
      output_block[r + (4 * c)] = state[r][c];
    }
  }
}

#define AES_BLOCK_SIZE 16

static void aes_encrypt(const uint8 *input, int input_len, uint8 *output, const uint8 *iv, const uint8 *key, int key_length) {
  uint8 input_block[AES_BLOCK_SIZE];

  while (input_len >= AES_BLOCK_SIZE) {
    memcpy(input_block, input, AES_BLOCK_SIZE);
    xor(input_block, iv, AES_BLOCK_SIZE); // implement CBC
    aes_block_encrypt(input_block, output, key, key_length);
    memcpy((void *) iv, (void *) output, AES_BLOCK_SIZE); // CBC
    input += AES_BLOCK_SIZE;
    output += AES_BLOCK_SIZE;
    input_len -= AES_BLOCK_SIZE;
  }
}

static void aes_decrypt(const uint8 *input, int input_len, uint8 *output, const uint8 *iv, const uint8 *key, int key_length) {
  while (input_len >= AES_BLOCK_SIZE) {
    aes_block_decrypt(input, output, key, key_length);
    xor(output, iv, AES_BLOCK_SIZE);
    memcpy((void *) iv, (void *) input, AES_BLOCK_SIZE); // CBC
    input += AES_BLOCK_SIZE;
    output += AES_BLOCK_SIZE;
    input_len -= AES_BLOCK_SIZE;
  }
}

void aes_128_encrypt(const uint8 *plaintext, const int plaintext_len, uint8 ciphertext[], void *iv, const uint8 *key) {
  aes_encrypt(plaintext, plaintext_len, ciphertext, (const uint8 *) iv, key, 16);
}

void aes_128_decrypt(const uint8 *ciphertext, const int ciphertext_len, uint8 plaintext[], void *iv, const uint8 *key) {
  aes_decrypt(ciphertext, ciphertext_len, plaintext, (const uint8 *) iv, key, 16);
}

void aes_256_encrypt(const uint8 *plaintext, const int plaintext_len, uint8 ciphertext[], void *iv, const uint8 *key) {
  aes_encrypt(plaintext, plaintext_len, ciphertext, (const uint8 *) iv, key, 32);
}

void aes_256_decrypt(const uint8 *ciphertext, const int ciphertext_len, uint8 plaintext[], void *iv, const uint8 *key) {
  aes_decrypt(ciphertext, ciphertext_len, plaintext, (const uint8 *) iv, key, 32);
}
