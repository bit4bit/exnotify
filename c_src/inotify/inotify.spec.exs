module Exnotify

interface CNode

callback :main

state_type "State"

# same events as inotify but with prefix NOTIFY_
type(
  events ::
    :notify_in_access
    | :notify_in_attrib
    | :notify_in_close_write
    | :notify_in_close_nowrite
    | :notify_in_create
    | :notify_in_delete
    | :notify_in_delete_self
    | :notify_in_modify
    | :notify_in_moved_from
    | :notify_in_moved_to
    | :notify_in_open
    | :notify_in_move
)

sends {:inotify_event :: label, wd :: int, name :: string, events :: [events]}

spec init() :: {:ok :: label, state} | {:error :: label, error :: string}

spec ex_inotify_add_watch(pathname :: string, events :: [events], opts :: int) ::
       {:ok :: label, wd :: int} | {:error :: label, error :: string}

spec ex_inotify_rm_watch(wd :: int) :: :ok | {:error :: label, error :: string}
