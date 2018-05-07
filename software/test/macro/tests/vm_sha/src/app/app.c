/*
 * File         : app.c
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   C99, 4 soft tab, wide column.
 *
 * Description:
 *   Compute SHA message digests.
 */
#include "sha.h"
#include "kernel.h"
#include <string.h>
#include <stdlib.h>

#define FAIL 0
#define PASS 1

// SHA1("Hello")
static uint8 res_sha1_1[20] = {
  0xf7, 0xff, 0x9e, 0x8b, 0x7b, 0xb2, 0xe0, 0x9b, 0x70, 0x93,
  0x5a, 0x5d, 0x78, 0x5e, 0x0c, 0xc5, 0xd9, 0xd0, 0xab, 0xf0
};

// SHA1(0{300})
static uint8 res_sha1_2[20] = {
  0xb2, 0x3b, 0x62, 0xbb, 0xd2, 0x2a, 0x60, 0x2b, 0x11, 0x30,
  0x38, 0xa0, 0x72, 0x17, 0xc6, 0xab, 0xcb, 0x15, 0x6f, 0x06
};

// SHA256(0{700})
static uint8 res_sha256_1[32] = {
  0x18, 0x2a, 0x1c, 0x0c, 0x5b, 0x24, 0xb5, 0xc7,
  0x86, 0x46, 0x76, 0xc8, 0xb9, 0x77, 0x6f, 0xad,
  0x26, 0x04, 0x1a, 0xdf, 0x27, 0x6f, 0xb3, 0xcd,
  0xa8, 0x4b, 0x17, 0x70, 0xe6, 0x28, 0x2a, 0x72
};

static int finish(int res) {
  disable_int(INT_TIMER);
  set_scratch(get_timer_bells());
  return res;
}

int test_sha1(void) {
  uint32 hash[sizeof(uint32) * SHA1_RESULT_SIZE];

  // Perform SHA1("Hello")
  char *decoded_input = "Hello";
  size_t decoded_len = strlen(decoded_input);
  memcpy(hash, sha1_initial_hash, sizeof(uint32) * SHA1_RESULT_SIZE);
  digest_hash((uint8 *)decoded_input, decoded_len, hash, sha1_block_operate, sha1_finalize);
  int res = memcmp(hash, res_sha1_1, sizeof(res_sha1_1));
  if (res != 0) {
    return FAIL;
  }

  // Perform SHA1(0x0{300})
  char *buf = malloc(300);
  if (buf == NULL) {
    return FAIL;
  }
  memset(buf, 0, 300);
  memcpy(hash, sha1_initial_hash, sizeof(uint32) * SHA1_RESULT_SIZE);
  digest_hash((uint8 *)buf, 300, hash, sha1_block_operate, sha1_finalize);
  res = memcmp(hash, res_sha1_2, sizeof(res_sha1_2));
  free(buf);
  if (res != 0) {
    return FAIL;
  }
  return PASS;
}

int test_sha256(void) {
  // Perform SHA256(0x0{700})
  digest_ctx *ctx = malloc(sizeof(digest_ctx));
  if (ctx == NULL) {
    return FAIL;
  }
  new_sha256_digest(ctx);
  char *buf = calloc(700, 1);
  if (buf == NULL) {
    return FAIL;
  }
  update_digest(ctx, (uint8 *)buf, 700);
  finalize_digest(ctx);
  int res = memcmp(ctx->hash, res_sha256_1, sizeof(res_sha256_1));
  free(ctx->hash);
  free(ctx);
  free(buf);
  if (res != 0) {
    return FAIL;
  }
  return PASS;
}

int main(void) {
  // Comment to disable periodic timer interrupts
  set_timer_cycles(500);
  enable_int(INT_TIMER);

  // Run tests for SHA1 and SHA256
  if (test_sha1() != PASS) {
    return finish(FAIL);
  }
  if (test_sha256() != PASS) {
    return finish(FAIL);
  }
  return finish(PASS);
}
