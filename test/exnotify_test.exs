defmodule ExnotifyTest do
  use ExUnit.Case
  doctest Exnotify

  describe "start link" do
    test "correctly starts as registered GenServer", config do
      start_supervised!({Exnotify, name: config.test})

      assert Process.whereis(config.test)
    end
  end

  describe "add_watch/4" do
    test "watch directory with defaults", config do
      start_supervised!({Exnotify, name: config.test})

      assert :ok = Exnotify.add_watch(config.test, System.tmp_dir())
    end

    test "watch creation", config do
      start_supervised!({Exnotify,
                         watcher: self(),
                         name: config.test})

      tmp_dir = System.tmp_dir()
      tmp_name = DateTime.utc_now() |> DateTime.to_unix(:microsecond) |> to_string() |> then(&("#{&1}.exnotify.test"))

      assert :ok = Exnotify.add_watch(config.test, tmp_dir)
      File.write!(Path.join(tmp_dir, tmp_name), "data")

      assert_receive {:inotify_event, _, tmp_name, _}
    end
  end
end
