defmodule Adapters.GlobalTest do
  use ExUnit.Case

  alias NodeChecker.Adapters

  setup_all do
    {:ok, _pid} = Adapters.Global.start_link([])
    :ok
  end

  def list(), do: Node.list()

  test "monitors node up and down events" do
    assert :ok = Adapters.Global.monitor_nodes(self)
    simulate_nodeup("some@node")
    assert_receive {:nodeup, "some@node"}

    simulate_nodedown("some@node")
    assert_receive {:nodedown, "some@node"}
  end

  test "demonitors node up and down events" do
    assert :ok = Adapters.Global.monitor_nodes(self)
    simulate_nodedown("some@node")
    assert_receive {:nodedown, "some@node"}
    assert :ok = Adapters.Global.demonitor_nodes(self)
    simulate_nodedown("some@node")
    refute_receive {:nodedown, "some@node"}
  end

  test "list returns active nodes" do
    assert Adapters.Global.list() == []
  end

  test "removes subscribers when they die" do
    assert subscribers() == %{}
    subscriber = spawn fn ->
      assert :ok = Adapters.Global.monitor_nodes(self)
      :timer.sleep(:infinity)
    end
    assert :ok = Adapters.Global.monitor_nodes(self)
    assert Map.keys(subscribers()) == [self, subscriber]
    Process.exit(subscriber, :kill)

    # avoids races for DOWN monitor
    simulate_nodedown("some@node")
    assert_receive {:nodedown, "some@node"}

    assert Map.keys(subscribers()) == [self]
  end

  defp simulate_nodeup(node_name),
    do: send(Adapters.Global, {:nodeup, node_name})

  defp simulate_nodedown(node_name),
    do: send(Adapters.Global, {:nodedown, node_name})

  defp subscribers(),
    do: GenServer.call(Adapters.Global, :subscribers)
end
