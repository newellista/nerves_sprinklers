defmodule NervesSprinklers.Repo.Migrations.CreateZoneGroups do
  use Ecto.Migration

  def change do
    create table(:zone_groups) do
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:zone_groups, [:name])
  end
end
