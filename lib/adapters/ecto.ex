defmodule NodeChecker.Adapters.Ecto do
  @moduledoc """
  The Repo strategy using Ecto to monitor node events
  """

  use GenServer
  import Ecto.Query

  # TODO remove stand-in repo
  defmodule Repo do
    use Ecto.Repo, otp_app: :node_checker
  end

  defmodule CNode do
    use Ecto.Model
    schema "node_checker_nodes" do
      field :name, :string
      timestamps
    end
  end

  @server __MODULE__

  @heartbeat Application.get_env(:node_checker, :heartbeat)
  @gc_window @heartbeat * 2

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
    repo       = opts[:repo] || raise ArgumentError, "Missing required :repo option for Ecto NodeChecker"
    name       = opts[:name] || raise ArgumentError, "Missing required :name option for Ecto NodeChecker"
    local_node = touch_updated_at(repo,
      repo.get_by(CNode, name: to_string(name)) || repo.insert!(%CNode{name: to_string(name)})
    )

    :timer.send_interval(@heartbeat, :heartbeat)
    :timer.send_interval(@gc_window, :garbage_collect)

    {:ok, %{nodes: list_nodes(repo, name),
            heartbeat: @heartbeat,
            local_node: local_node,
            name: name,
            subscribers: %{},
            repo: repo}}
  end

  def handle_info(:heartbeat, %{repo: repo} = state) do
    {:noreply, state
               |> remove_nodes(state.nodes -- list_nodes(repo, state.name))
               |> add_nodes(list_nodes(repo, state.name) -- state.nodes)
               |> update_in([:local_node], &touch_updated_at(repo, &1))}
  end

  def handle_info(:garbage_collect, %{repo: repo} = state) do
    # TODO find better way to fetch by interval that is driver agnostic
    dead_nodes =
      from(n in CNode,
      where: n.name != ^to_string(state.name),
      where: fragment("updated_at + INTERVAL '? milliseconds' < ?",
                      @gc_window, ^Ecto.DateTime.utc))
      |> repo.delete_all()
      |> case do
        {0, _} -> []
        {_, _} -> state.nodes -- list_nodes(repo, state.name)
      end

    {:noreply, remove_nodes(state, dead_nodes)}
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
    repo.update!(local_node, force: true)
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
   where: n.name != ^to_string(own_name),
   select: n.name)
   |> repo.all()
   |> Enum.map(&String.to_atom(&1))
  end
end
