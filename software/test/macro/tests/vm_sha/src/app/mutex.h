#ifndef MUTEX_H
#define MUTEX_H

#include <stdbool.h>

void mutex_init(int *mutex);
void mutex_lock(int *mutex);
bool mutex_try_lock(int *mutex);
void mutex_unlock(int *mutex);

#endif  // MUTEX_H
