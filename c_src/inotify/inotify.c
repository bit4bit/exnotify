#include <sys/inotify.h>
#include <string.h>
#include <poll.h>
#include <unistd.h>

#include "inotify.h"


static struct mask_to_event_t {
  int mask;
  Events event;
} mask_to_event[] = {
  {IN_CREATE, NOTIFY_IN_CREATE},
  {IN_DELETE, NOTIFY_IN_DELETE},
  {-1, -1}
};

unsigned int events_to_mask(Events*, unsigned int);
void mask_to_events(unsigned int mask, Events* events, unsigned int *events_length);

UNIFEX_TERM init(UnifexEnv *env) {
  int fd = inotify_init1(IN_NONBLOCK);
  State *state = unifex_alloc_state(env);
  state->inotify_fd = fd;

  if (fd == -1)
    return init_result_error(env, strerror(errno));

  UNIFEX_TERM res = init_result_ok(env, state);
  unifex_release_state(env, state);
  return res;
}

UNIFEX_TERM ex_inotify_add_watch(UnifexEnv* env, char* pathname, Events* events, unsigned int events_length, int opts) {
  State *state = (State *) env->state;
  unsigned int mask = events_to_mask(events, events_length) | opts;

  if (state == NULL)
    return ex_inotify_add_watch_result_error(env, "not initialized");

  int wd = inotify_add_watch(state->inotify_fd, pathname, mask);

  if (wd == -1)
    return ex_inotify_add_watch_result_error(env, strerror(errno));
  else
    return ex_inotify_add_watch_result_ok(env, wd);
}

UNIFEX_TERM ex_inotify_rm_watch(UnifexEnv* env, int wd) {
  State *state = (State *) env->state;
  int ret = inotify_rm_watch(state->inotify_fd, wd);

  if (state == NULL)
    return ex_inotify_add_watch_result_error(env, "not initialized");

  if (ret == -1)
    return ex_inotify_rm_watch_result_error(env, strerror(errno));
  else
    return ex_inotify_rm_watch_result(env);
}

int handle_events(UnifexEnv *env, int fd) {
  char buf[4096];
  const struct inotify_event *event;
  ssize_t len;

  if (env->state == NULL)
    return 0;

  // TOMADO DE man inotify
  for (;;) {
    len = read(fd, buf, sizeof(buf));
    if (len == -1 && errno != EAGAIN) {
      return -1;
    }

    if (len <= 0)
      break;

    for (char *ptr = buf; ptr < buf + len;
         ptr += sizeof(struct inotify_event) + event->len) {
      Events myevents[10];
      unsigned int myevents_length = 0;
      event = (const struct inotify_event *) ptr;

      mask_to_events(event->mask, myevents, &myevents_length);

      send_inotify_event(env, *env->reply_to, 0, event->wd, event->name, myevents, 1);
    }
  }

  return 0;
}

int handle_main(int argc, char **argv) {
  UnifexEnv env;
  int poll_num;
  nfds_t nfds = 3;
  struct pollfd fds[3];
  int done = 0;

  if (unifex_cnode_init(argc, argv, &env)) {
    return 1;
  }

  while (!done) {
    State* state = (State *)env.state;
    if (state == NULL) {
      done = unifex_cnode_receive(&env);
    } else {
      fds[0].fd = state->inotify_fd;
      fds[0].events = POLLIN;

      fds[1].fd = env.ei_socket_fd;
      fds[1].events = POLLIN;

      fds[2].fd = env.listen_fd;
      fds[2].events = POLLIN;

      poll_num = poll(fds, nfds, -1);

      if (poll_num == -1) {
        if (errno == EINTR)
          continue;
        done = 1;
        break;
      }

      if (poll_num > 0) {
        if (fds[0].revents & POLLIN) {
          if (handle_events(&env, fds[0].fd) != 0)
            break;
        }

        if (fds[1].revents & POLLIN) {
          done = unifex_cnode_receive(&env);
        }

        if (fds[2].revents & POLLIN) {
          done = unifex_cnode_receive(&env);
        }
      }
    }
  }


  unifex_cnode_destroy(&env);
  return 0;
}



void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);
  close(state->inotify_fd);
}

void mask_to_events(unsigned int mask, Events* events, unsigned int *events_length) {
  int j = 0;

  for(struct mask_to_event_t *map = mask_to_event; map != NULL; map += 1) {
    if (map->mask == -1)
      break;

    if (mask & map->mask) {
      events[j] = map->event;
      j++;
    }
  }

  *events_length = j + 1;
}

unsigned int events_to_mask(Events* events, unsigned int events_length) {
  unsigned int mask = 0;


  for(unsigned  i = 0; i < events_length; i++) {
    for(struct mask_to_event_t *map = mask_to_event; map != NULL; map += 1) {
      if (map->mask == -1)
      break;

      if (events[i] == map->event) {
        mask |= map->mask;
      }
    }
  }

  return mask;
}
