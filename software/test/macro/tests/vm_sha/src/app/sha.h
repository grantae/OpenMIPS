#ifndef SHA_H
#define SHA_H

/* This code is derived from the book
 * "Implementing SSL / TLS Using Cryptography and PKI" by Joshua Davies.
 *
 * Do not use this for real applications!
 */

#include "fixed-types.h"
#include "digest.h"

#define SHA1_RESULT_SIZE 5
#define SHA1_BYTE_SIZE SHA1_RESULT_SIZE * sizeof(int)

#define SHA256_RESULT_SIZE 8
#define SHA256_BYTE_SIZE SHA256_RESULT_SIZE * sizeof(int)

uint32 sha1_initial_hash[ SHA1_RESULT_SIZE ];
void sha1_block_operate(const uint8 *block, uint32 hash[ SHA1_RESULT_SIZE ]);
void sha1_finalize(uint8 *padded_block, int32 length_in_bits);
void new_sha1_digest(digest_ctx *context);
void new_sha256_digest(digest_ctx *context);

#endif  // SHA_H
