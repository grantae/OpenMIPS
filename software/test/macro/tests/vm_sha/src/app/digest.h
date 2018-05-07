#ifndef DIGEST_H
#define DIGEST_H

/* This code is derived from the book
 * "Implementing SSL / TLS Using Cryptography and PKI" by Joshua Davies.
 *
 * Do not use this for real applications!
 */

#include "fixed-types.h"

int32 digest_hash(uint8 *input,
    int32 len,
    uint32 *hash,
    void (*block_operate)(const uint8 *input, uint32 hash[]),
    void (*block_finalize)(uint8 *block, int32 length));

#define DIGEST_BLOCK_SIZE 64
#define INPUT_BLOCK_SIZE 56

typedef struct {
  uint32 *hash;
  int32 hash_len;
  uint32 input_len;

  void (*block_operate)(const uint8 *input, uint32 hash[]);
  void (*block_finalize)(uint8 *block, int32 length);

  // Temporary storage
  unsigned char block[DIGEST_BLOCK_SIZE];
  int32 block_len;
} digest_ctx;

void update_digest(digest_ctx *context, const uint8 *input, int32 input_len);
void finalize_digest(digest_ctx *context);

#endif  // DIGEST_H
