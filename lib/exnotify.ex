defmodule Exnotify do
  @moduledoc """
  Documentation for `Exnotify`.
  """
  use GenServer

  require Unifex.CNode

  defstruct [:cnode, :watcher, watch_descriptors: %{}]

  @doc """
  Start the GenServer.

  ## Options

  - `:name` - The name for locally registered as. By default is `Exnotify`
  - `:watcher` - The pid of watcher events. By default is pid of caller
  """
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    watcher = opts[:watcher] || self()

    GenServer.start_link(__MODULE__, watcher, name: name)
  end

  @doc """
  Watch for events on directory or file.

  """
  @spec add_watch(
          name :: GenServer.t(),
          pathname :: String.t(),
          events :: [
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
          ],
          opts :: []
        ) :: :ok | {:error, any()}
  def add_watch(name, pathname, events \\ [:notify_in_create], opts \\ []) do
    GenServer.call(name, {:add_watch, pathname, events, opts})
  end

  @impl true
  def init(watcher) do
    case Unifex.CNode.start_link(:inotify) do
      {:ok, cnode} ->
        case call(cnode, :init, []) do
          :ok ->
            Process.flag(:trap_exit, true)
            {:ok, %Exnotify{cnode: cnode, watcher: watcher}}

          _ ->
            {:stop, :cnode}
        end

      _ ->
        {:stop, :cnode}
    end
  end

  @impl true
  def handle_call({:add_watch, pathname, events, _opts}, _from, state) do
    case call(state.cnode, :ex_inotify_add_watch, [pathname, events, 0]) do
      {:ok, wd} ->
        watch_descriptors = Map.put(state.watch_descriptors, pathname, wd)

        {:reply, :ok, %{state | watch_descriptors: watch_descriptors}}

      {:error, errno} ->
        {:reply, {:error, errno}, state}
    end
  end

  @impl true
  def handle_info({:inotify_event, _, _, _} = event, state) do
    send(state.watcher, event)
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _from, _reason}, state) do
    {:stop, :cnode, state}
  end

  @impl true
  def terminate(:cnode, _state) do
    {:shutdown, :cnode}
  end

  @impl true
  def terminate(reason, state) do
    for {_pathname, wd} <- state.watch_descriptors do
      call(state.cnode, :ex_inotify_rm_watch, [wd])
    end

    reason
  end

  defp call(cnode, fun, args) when is_list(args) do
    apply(Unifex.CNode, :call, [cnode, fun, args])
  end
end
