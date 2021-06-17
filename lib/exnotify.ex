defmodule Exnotify do
  @moduledoc """
  Documentation for `Exnotify`.
  """
  use GenServer

  require Unifex.CNode

  defstruct [:cnode, :watcher, watch_descriptors: %{}]

  def start_link(opts \\ []) do
    {watcher, opts} = Keyword.pop(opts, :watcher, self())
    GenServer.start_link(__MODULE__, watcher, opts)
  end

  def add_watch(name, pathname, events \\ [:notify_in_create], opts \\ []) do
    GenServer.call(name, {:add_watch, pathname, events, opts})
  end

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

  def handle_call({:add_watch, pathname, events, opts}, _from, state) do
    case call(state.cnode, :ex_inotify_add_watch, [pathname, events, 0]) do
      {:ok, wd} ->
        watch_descriptors = Map.put(state.watch_descriptors, pathname, wd)

        {:reply, :ok, %{state | watch_descriptors: watch_descriptors}}

      {:error, errno} ->
        {:reply, {:error, errno}, state}
    end
  end

  def handle_info({:inotify_event, _, _, _} = event, state) do
    send(state.watcher, event)
    {:noreply, state}
  end

  def handle_info({:EXIT, _from, _reason}, state) do
    {:stop, :cnode, state}
  end

  def terminate(:cnode, _state) do
    {:shutdown, :cnode}
  end

  def terminate(reason, state) do
    for {_pathname, wd} <- state.watch_descriptors do
      call(state.cnode, :ex_inotify_rm_watch, [wd])
    end

    reason
  end

  defp call(cnode, fun, args \\ []) when is_list(args) do
    apply(Unifex.CNode, :call, [cnode, fun, args])
  end

  defp errno_to_atom(_errno) do
    :einval
  end
end
