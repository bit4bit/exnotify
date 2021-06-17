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
      start_supervised!({Exnotify, watcher: self(), name: config.test})
      tmp_dir = System.tmp_dir()
      tmp_path = tmp_file(tmp_dir)
      tmp_name = Path.basename(tmp_path)

      assert :ok = Exnotify.add_watch(config.test, tmp_dir)
      File.write!(tmp_path, "data")

      assert_receive {:inotify_event, _, ^tmp_name, [:notify_in_create, :notify_in_access]}
    end

    test "watch in close", config do
      start_supervised!({Exnotify, watcher: self(), name: config.test})

      tmp_dir = System.tmp_dir()
      :ok = Exnotify.add_watch(config.test, tmp_dir, [:notify_in_create, :notify_in_close_write])

      tmp_path = tmp_file(tmp_dir)
      tmp_name = Path.basename(tmp_path)

      File.open(tmp_path, [:write], fn _file ->
        assert_receive {:inotify_event, _, ^tmp_name, [:notify_in_create, :notify_in_access]}
      end)

      assert_receive {:inotify_event, _, ^tmp_name, [:notify_in_close_write, :notify_in_access]}
    end

    test "watch in delete", config do
      start_supervised!({Exnotify, watcher: self(), name: config.test})
      tmp_dir = System.tmp_dir()
      tmp_path = tmp_file(tmp_dir)
      tmp_name = Path.basename(tmp_path)
      File.write!(tmp_path, "test")

      :ok = Exnotify.add_watch(config.test, tmp_dir, [:notify_in_delete])
      File.rm!(tmp_path)

      assert_receive {:inotify_event, _, ^tmp_name, [:notify_in_delete, :notify_in_access]}
    end
  end

  def tmp_file(dir) do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> to_string()
    |> then(&"#{&1}.exnotify.test")
    |> then(&Path.join(dir, &1))
  end
end
