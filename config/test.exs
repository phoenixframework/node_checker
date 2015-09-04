use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

config :node_checker, NodeChecker.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "node_checker_test",
  username: "postgres",
  password: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  size: 1,
  max_overflow: 0
