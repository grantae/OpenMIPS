#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "digest.h"

/**
 * Generic digest hash computation. The hash should be set to its initial
 * value *before* calling this function.
 */
int32 digest_hash(uint8 *input, int32 len, uint32 *hash,
    void (*block_operate)(const uint8 *input, uint32 hash[]),
    void (*block_finalize)(uint8 *block, int32 length)) {

  uint8 padded_block[DIGEST_BLOCK_SIZE];
  int32 length_in_bits = len * 8;

  while (len >= INPUT_BLOCK_SIZE) {
    // Special handling for blocks between 56 and 64 bytes
    // (not enough room for the 8 bytes of length, but also
    // not enough to fill up a block)
    if (len < DIGEST_BLOCK_SIZE) {
      memset(padded_block, 0, sizeof(padded_block));
      memcpy(padded_block, input, len);
      padded_block[len] = 0x80;
      block_operate(padded_block, hash);
      input += len;
      len = -1;
    } else {
      block_operate(input, hash);
      input += DIGEST_BLOCK_SIZE;
      len -= DIGEST_BLOCK_SIZE;
    }
  }

  memset(padded_block, 0, sizeof(padded_block));
  if (len >= 0) {
    memcpy(padded_block, input, len);
    padded_block[len] = 0x80;
  }
  block_finalize(padded_block, length_in_bits);
  block_operate(padded_block, hash);
  return 0;
}

void update_digest(digest_ctx *context, const uint8 *input, int32 input_len) {
  context->input_len += input_len;

  // Process any left over from the last call to "update_digest"
  if (context->block_len > 0) {
    // How much we need to make a full block
    int32 borrow_amt = DIGEST_BLOCK_SIZE - context->block_len;

    if (input_len < borrow_amt) {
      memcpy(context->block + context->block_len, input, input_len);
      context->block_len += input_len;
      input_len = 0;
    } else {
      memcpy(context->block + context->block_len, input, borrow_amt);
      context->block_operate(context->block, context->hash);
      context->block_len = 0;
      input += borrow_amt;
      input_len -= borrow_amt;
    }
  }

  while (input_len >= DIGEST_BLOCK_SIZE) {
    context->block_operate(input, context->hash);
    input += DIGEST_BLOCK_SIZE;
    input_len -= DIGEST_BLOCK_SIZE;
  }

  // Have some non-aligned data left over; save it for next call, or
  // "finalize" call.
  if (input_len > 0) {
    memcpy(context->block, input, input_len);
    context->block_len = input_len;
  }
}

/**
 * Process whatever's left over in the context buffer, append
 * the length in bits, and update the hash one last time.
 */
void finalize_digest(digest_ctx *context) {
  memset(context->block + context->block_len, 0, DIGEST_BLOCK_SIZE - context->block_len);
  context->block[context->block_len] = 0x80;
  // special handling if the last block is < 64 but > 56
  if (context->block_len >= INPUT_BLOCK_SIZE) {
    context->block_operate(context->block, context->hash);
    context->block_len = 0;
    memset(context->block + context->block_len, 0, DIGEST_BLOCK_SIZE -
    context->block_len);
  }
  // Only append the length for the very last block
  // Technically, this allows for 64 bits of length, but since we can only
  // process 32 bits worth, we leave the upper four bytes empty
  context->block_finalize(context->block, context->input_len * 8);

  context->block_operate(context->block, context->hash);
}
