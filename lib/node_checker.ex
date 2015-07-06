defmodule NodeChecker do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(adapter(), [[]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
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
