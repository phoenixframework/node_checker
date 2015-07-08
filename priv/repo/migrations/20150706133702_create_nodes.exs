defmodule NodeChecker.Adapters.Ecto.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:node_checker_nodes) do
      add :name, :string
      timestamps
    end

    create index(:node_checker_nodes, [:name], unique: true)
  end
end
