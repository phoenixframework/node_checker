use Mix.Config

config :node_checker,
  heartbeat: 5000,
  adapter: NodeChecker.Adapters.Ecto

config :node_checker, NodeChecker.Adapters.Ecto.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "node_checker_dev",
  username: "postgres",
  password: "postgres"
