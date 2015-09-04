ExUnit.start()
NodeChecker.Adapters.Ecto.Repo.start_link()
# Create the database, run migrations, and start the test transaction.
Mix.Task.run "ecto.create", ["-r", "NodeChecker.Adapters.Ecto.Repo", "--quiet"]
Mix.Task.run "ecto.migrate", ["-r", "NodeChecker.Adapters.Ecto.Repo", "--quiet"]
Ecto.Adapters.SQL.begin_test_transaction(NodeChecker.Adapters.Ecto.Repo)
