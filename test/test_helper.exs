ExUnit.start()

NodeChecker.Repo.start_link()
# Create the database, run migrations, and start the test transaction.
Mix.Task.run "ecto.create", ["-r", "NodeChecker.Repo", "--quiet"]
Mix.Task.run "ecto.migrate", ["-r", "NodeChecker.Repo", "--quiet"]
Ecto.Adapters.SQL.begin_test_transaction(NodeChecker.Repo)
