use Mix.Config

config :node_checker,
  adapter: NodeChecker.Adapters.Ecto

config :node_checker, NodeChecker.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "node_checker_dev",
  username: "postgres",
  password: "postgres"
