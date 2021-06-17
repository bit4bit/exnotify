#pragma once

typedef struct State State;
#include "_generated/inotify.h"

struct State  {
  int inotify_fd;
};
