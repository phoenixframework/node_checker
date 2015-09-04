defmodule NodeChecker.Adapters.Ecto do
  @moduledoc """
  The Repo strategy using Ecto to monitor node events
  """

  @behaviour NodeChecker.Adapter
  use GenServer
  import Ecto.Query

  defmodule CNode do
    use Ecto.Model
    schema "node_checker_nodes" do
      field :name, :string
      timestamps
    end
  end

  @server __MODULE__

  @heartbeat 5000

  ## Client API

  def monitor_nodes(pid) do
    GenServer.call(@server, {:monitor_nodes, pid})
  end

  def demonitor_nodes(pid) do
    GenServer.call(@server, {:demonitor_nodes, pid})
  end

  def list() do
    GenServer.call(@server, :list)
  end


  ## Server API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @server)
  end

  def init(opts) do
    heartbeat  = opts[:heartbeat] || @heartbeat
    gc_window  = heartbeat * 2
    repo       = op!(opts, :repo)
    name       = op!(opts, :name) |> to_string()

    send(self, :setup_nodes)

    :timer.send_interval(heartbeat, :heartbeat)
    :timer.send_interval(gc_window, :garbage_collect)

    {:ok, %{nodes: [],
            heartbeat: heartbeat,
            gc_window_seconds: window_to_seconds(gc_window),
            local_node: nil,
            name: name,
            subscribers: %{},
            repo: repo}}
  end
  defp op!(opts, key) do
    opts[key] || raise(ArgumentError, "Missing required option :#{key} for NodeChecker")
  end

  def handle_info(:setup_nodes, %{repo: repo, name: name} = state) do
    local_node = case repo.get_by(CNode, name: name) do
      %CNode{} = cnode -> touch_updated_at(repo, cnode)
      nil              -> repo.insert!(%CNode{name: name})
    end

    {:noreply, %{state | local_node: local_node,
                         nodes: list_nodes(repo, name)}}
  end

  def handle_info(:heartbeat, %{repo: repo} = state) do
    fresh_node_list = list_nodes(repo, state.name)
    {:noreply, state
               |> remove_nodes(state.nodes -- fresh_node_list)
               |> add_nodes(fresh_node_list -- state.nodes)
               |> update_in([:local_node], &touch_updated_at(repo, &1))}
  end

  def handle_info(:garbage_collect, %{repo: repo} = state) do
    state
    |> dead_nodes()
    |> repo.delete_all()

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, remove_subscriber(state, pid)}
  end

  def handle_call({:monitor_nodes, pid}, _from, state) do
    {:reply, :ok, add_subscriber(state, pid, Process.monitor(pid))}
  end

  def handle_call({:demonitor_nodes, pid}, _from, state) do
    Process.demonitor(Map.get(state.subscribers, pid))
    {:reply, :ok, remove_subscriber(state, pid)}
  end

  def handle_call(:list, _from, state) do
    {:reply, list_nodes(state.repo, state.name), state}
  end

  def handle_call(:subscribers, _from, state) do
    {:reply, state.subscribers, state}
  end

  defp remove_subscriber(state, pid),
    do: %{state | subscribers: Map.delete(state.subscribers, pid)}

  defp add_subscriber(state, pid, ref),
    do: %{state | subscribers: Map.put(state.subscribers, pid, ref)}

  defp touch_updated_at(repo, local_node) do
    # TODO remove hack once bug is fixed in ecto
    # https://github.com/elixir-lang/ecto/issues/920
    repo.update!(%CNode{local_node | updated_at: Ecto.DateTime.utc}, force: true)
  end

  defp remove_nodes(state, []), do: state
  defp remove_nodes(state, dead_nodes) do
    for {pid, _ref} <- state.subscribers do
      for dead_node <- dead_nodes do
        send(pid, {:nodedown, dead_node})
      end
    end

    %{state | nodes: state.nodes -- dead_nodes}
  end

  defp add_nodes(state, []), do: state
  defp add_nodes(state, added_nodes) do
    for {pid, _ref} <- state.subscribers do
      for added_node <- added_nodes do
        send(pid, {:nodeup, added_node})
      end
    end

    %{state | nodes: state.nodes ++ added_nodes}
  end

  defp list_nodes(repo, own_name) do
    from(n in CNode,
    where: n.name != ^own_name,
    select: n.name)
    |> repo.all()
    |> Enum.map(&String.to_atom(&1))
  end

  defp window_to_seconds(ms) do
    case trunc(ms / 1000) do
      0 -> 1
      secs -> secs
    end
  end

  defp dead_nodes(%{gc_window_seconds: secs} = state) do
      from n in CNode,
    where: n.name != ^state.name,
    where: n.updated_at < datetime_add(^Ecto.DateTime.utc, ^-secs, "second")
  end
end
