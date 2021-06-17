module Exnotify

interface CNode

callback :main

state_type "State"

type events :: :notify_in_create | :notify_in_delete

sends {:inotify_event :: label, wd :: int, name :: string, events :: [events]}

spec init() :: {:ok :: label, state} | {:error :: label, error :: string}

spec ex_inotify_add_watch(pathname :: string, events :: [events], opts :: int) :: {:ok :: label, wd :: int} | {:error :: label, error :: string}
spec ex_inotify_rm_watch(wd :: int) :: :ok | {:error :: label, error :: string}
