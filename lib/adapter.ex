defmodule NodeChecker.Adapter do
  @moduledoc """
  The Behaviour for defining a NodeChecker Adapter
  """

  use Behaviour

  defcallback start_link(opts :: List.t) :: {:ok, Pid} | {:error, reason :: term}

  defcallback monitor_nodes(pid :: Pid) :: :ok | {:error, reason :: term}

  defcallback demonitor_nodes(pid :: Pid) :: :ok | {:error, reason :: term}

  defcallback list() :: node_list :: List.t
end
