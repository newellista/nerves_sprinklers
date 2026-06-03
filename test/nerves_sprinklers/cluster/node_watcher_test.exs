defmodule NervesSprinklers.Cluster.NodeWatcherTest do
  use ExUnit.Case, async: true

  alias NervesSprinklers.Cluster.NodeWatcher

  setup do
    pid = Process.whereis(NodeWatcher)
    %{pid: pid}
  end

  test "connected_nodes includes local node", %{pid: _pid} do
    assert node() in NodeWatcher.connected_nodes()
  end

  test "nodeup adds node to connected_nodes", %{pid: pid} do
    fake = :"fake_nodeup_#{System.unique_integer([:positive])}@host"
    send(pid, {:nodeup, fake, []})
    _ = NodeWatcher.connected_nodes()
    assert fake in NodeWatcher.connected_nodes()
  end

  test "nodedown removes node from connected_nodes", %{pid: pid} do
    fake = :"fake_nodedown_#{System.unique_integer([:positive])}@host"
    send(pid, {:nodeup, fake, []})
    _ = NodeWatcher.connected_nodes()
    send(pid, {:nodedown, fake, []})
    _ = NodeWatcher.connected_nodes()
    refute fake in NodeWatcher.connected_nodes()
  end

  test "nodedown does not crash watcher when node is not running executor", %{pid: pid} do
    fake = :"fake_nocrash_#{System.unique_integer([:positive])}@host"
    send(pid, {:nodeup, fake, []})
    _ = NodeWatcher.connected_nodes()
    send(pid, {:nodedown, fake, []})
    _ = NodeWatcher.connected_nodes()
    refute fake in NodeWatcher.connected_nodes()
    assert Process.alive?(pid)
  end
end
