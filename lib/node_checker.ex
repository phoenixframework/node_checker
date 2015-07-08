defmodule NodeChecker do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
    ]

    opts = [strategy: :one_for_one, name: NodeChecker.Supervisor]
    Supervisor.start_link(children, opts)
  end


 ## Client API

  def monitor_nodes(pid) do
    adapter().monitor_nodes(pid)
  end

  def demonitor_nodes(pid) do
    adapter().demonitor_nodes(pid)
  end

  def list() do
    adapter().list()
  end

  defp adapter() do
    Application.get_env(:node_checker, :adapter, NodeChecker.Adapters.Global)
  end
end
