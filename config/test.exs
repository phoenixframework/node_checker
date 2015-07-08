use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

config :node_checker, heartbeat: 45

config :node_checker, NodeChecker.Adapters.Ecto.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "node_checker_test",
  username: "postgres",
  password: "postgres",
  size: 1,
  max_overflow: 0
