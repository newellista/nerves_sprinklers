defmodule NervesSprinklers.Repo.Migrations.CreateZoneGroupMembers do
  use Ecto.Migration

  def change do
    create table(:zone_group_members) do
      add :zone_id, references(:zones, on_delete: :delete_all), null: false
      add :zone_group_id, references(:zone_groups, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:zone_group_members, [:zone_id, :zone_group_id])
  end
end
