#ifndef AES_H
#define AES_H

/* This code is derived from the book
 * "Implementing SSL / TLS Using Cryptography and PKI" by Joshua Davies.
 *
 * Do not use this for real applications!
 */

#include "fixed-types.h"

void aes_128_encrypt(const uint8 *plaintext,
    const int plaintext_len,
    uint8 ciphertext[],
    void *iv,
    const uint8 *key);

void aes_128_decrypt(const uint8 *ciphertext,
    const int ciphertext_len,
    uint8 plaintext[],
    void *iv,
    const uint8 *key);

void aes_256_encrypt(const uint8 *plaintext,
    const int plaintext_len,
    uint8 ciphertext[],
    void *iv,
    const uint8 *key);

void aes_256_decrypt(const uint8 *ciphertext,
    const int ciphertext_len,
    uint8 plaintext[],
    void *iv,
    const uint8 *key);

#endif  // AES_H
