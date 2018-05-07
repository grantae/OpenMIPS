#ifndef ENDIAN_H
#define ENDIAN_H

#include "fixed-types.h"
#include <stdbool.h>

// Note: We could pass a definition in instead
static inline bool be() {
  union {
    uint32 i;
    char c[4];
  } value = {0x01020304};

  return value.c[0] == 1;
}

static inline uint16 swap_u16(uint16 val) {
  return (val << 8) | (val >> 8);
}

static inline int16 swap_s16(int16 val) {
  uint16 uval = (uint16)val;
  return (int16)swap_u16(uval);
}

static inline uint32 swap_u32(uint32 val) {
  val = ((val << 8) & 0xff00ff00) | ((val >> 8) & 0xff00ff);
  return (val << 16) | (val >> 16);
}

static inline int32 swap_s32(int32 val) {
  uint32 uval = (uint32)val;
  return (int32)swap_u32(uval);
}


// Convert native to big endian

static inline uint16 n2be_u16(uint16 val) {
  return (be()) ? val : swap_u16(val);
}

static inline int16 n2be_s16(int16 val) {
  return (be()) ? val : swap_s16(val);
}

static inline uint32 n2be_u32(uint32 val) {
  return (be()) ? val : swap_u32(val);
}

static inline int32 n2be_s32(int32 val) {
  return (be()) ? val : swap_s32(val);
}

// Convert native to little endian

static inline uint16 n2le_u16(uint16 val) {
  return (be()) ? swap_u16(val) : val;
}

static inline int16 n2le_s16(int16 val) {
  return (be()) ? swap_s16(val) : val;
}

static inline uint32 n2le_u32(uint32 val) {
  return (be()) ? swap_u32(val) : val;
}

static inline int32 n2le_s32(int32 val) {
  return (be()) ? swap_s32(val) : val;
}


// Convert big endian to native

static inline uint16 be2n_u16(uint16 val) {
  return (be()) ? val : swap_u16(val);
}

static inline int16 be2n_s16(int16 val) {
  return (be()) ? val : swap_s16(val);
}

static inline uint32 be2n_u32(uint32 val) {
  return (be()) ? val : swap_u32(val);
}

static inline int32 be2n_s32(int32 val) {
  return (be()) ? val : swap_s32(val);
}


// Convert little endian to native

static inline uint16 le2n_u16(uint16 val) {
  return (be()) ? swap_u16(val) : val;
}

static inline int16 le2n_s16(int16 val) {
  return (be()) ? swap_s16(val) : val;
}

static inline uint32 le2n_u32(uint32 val) {
  return (be()) ? swap_u32(val) : val;
}

static inline int32 le2n_s32(int32 val) {
  return (be()) ? swap_s32(val) : val;
}

#endif  // ENDIAN_H
