defmodule NodeChecker.AdapterTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  alias NodeChecker.Adapters
  alias NodeChecker.Adapters.Ecto.CNode
  alias NodeChecker.Repo

  @adapters %{
    Adapters.Global => [],
    Adapters.Ecto => [repo: Repo, name: :"ecto@host", heartbeat: 45],
  }

  defp setup_adapter(Adapters.Ecto, opts) do
    Repo.delete_all(CNode)
    {:ok, _pid} = Adapters.Ecto.start_link(opts)
  end
  defp setup_adapter(Adapters.Global, opts) do
    {:ok, _pid} = Adapters.Global.start_link(opts)
  end

  ## Shared Adapter tests
  for {adapter, opts} <- @adapters do
    @adapter adapter
    @adapter_opts opts

    setup do
      setup_adapter(@adapter, @adapter_opts)
      :ok
    end

    test "#{@adapter} monitors node up and down events" do
      assert :ok = @adapter.monitor_nodes(self)
      simulate_nodeup(@adapter, :"some1@node")
      assert_receive {:nodeup, :"some1@node"}

      simulate_nodedown(@adapter, :"some1@node")
      assert_receive {:nodedown, :"some1@node"}
    end

    test "#{@adapter} demonitors node up and down events" do
      assert :ok = @adapter.monitor_nodes(self)
      simulate_nodeup(@adapter, :"some2@node")
      assert_receive {:nodeup, :"some2@node"}
      simulate_nodedown(@adapter, :"some2@node")
      assert_receive {:nodedown, :"some2@node"}
      assert :ok = @adapter.demonitor_nodes(self)
      simulate_nodedown(@adapter, :"some3@node")
      refute_receive {:nodedown, :"some3@node"}
    end

    test "#{@adapter} removes subscribers when they die" do
      assert subscribers(@adapter) == %{}
      subscriber = spawn fn ->
        assert :ok = @adapter.monitor_nodes(self)
        :timer.sleep(:infinity)
      end
      assert :ok = @adapter.monitor_nodes(self)
      assert Map.keys(subscribers(@adapter)) == [self, subscriber]
      Process.exit(subscriber, :kill)

      # avoids races for DOWN monitor
      simulate_nodeup(@adapter, :"some4@node")
      assert_receive {:nodeup, :"some4@node"}

      assert Map.keys(subscribers(@adapter)) == [self]
    end
  end


  ## Custom Adapter tests

  test "Global list returns active nodes" do
    assert Adapters.Global.list() == []
  end

  test "Ecto list returns active nodes" do
    assert :ok = Adapters.Ecto.monitor_nodes(self)
    assert Adapters.Ecto.list() == []
    simulate_nodeup(Adapters.Ecto, :"some5@node")
    simulate_nodeup(Adapters.Ecto, :"some6@node")
    assert_receive {:nodeup, :"some5@node"}
    assert_receive {:nodeup, :"some6@node"}
    assert Adapters.Ecto.list() == [:"some5@node", :"some6@node"]

    simulate_nodedown(Adapters.Ecto, :"some5@node")
    simulate_nodedown(Adapters.Ecto, :"some6@node")
    assert_receive {:nodedown, :"some5@node"}
    assert_receive {:nodedown, :"some6@node"}
    assert Adapters.Ecto.list() == []
  end

  test "Ecto nodes are garbage collected afer no heartbeat" do
    assert :ok = Adapters.Ecto.monitor_nodes(self)
    simulate_nodeup(Adapters.Ecto, :"some7@node")
    simulate_nodeup(Adapters.Ecto, :"some8@node")
    assert_receive {:nodeup, :"some7@node"}
    assert_receive {:nodeup, :"some8@node"}
    assert Adapters.Ecto.list() == [:"some7@node", :"some8@node"]

    assert_receive {:nodedown, :"some7@node"}, 2000
    assert_receive {:nodedown, :"some8@node"}, 2000
  end

  defp simulate_nodeup(Adapters.Global = adapter, node_name) do
    send(adapter, {:nodeup, node_name})
  end
  defp simulate_nodeup(Adapters.Ecto = _adapter, node_name) do
    Repo.insert!(%CNode{name: to_string(node_name)})
  end

  defp simulate_nodedown(Adapters.Global = adapter, node_name) do
    send(adapter, {:nodedown, node_name})
  end
  defp simulate_nodedown(Adapters.Ecto = _adapter, node_name) do
    from(n in CNode, where: n.name == ^to_string(node_name))
    |> Repo.delete_all()
  end

  defp subscribers(adapter),
    do: GenServer.call(adapter, :subscribers)
end
