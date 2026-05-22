defmodule NervesSprinklers.Repo.Migrations.CreateScheduleZones do
  use Ecto.Migration

  def change do
    create table(:schedule_zones) do
      add :schedule_id, references(:schedules, on_delete: :delete_all), null: false
      add :zone_id, references(:zones, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :duration_sec, :integer, null: false

      timestamps()
    end

    create unique_index(:schedule_zones, [:schedule_id, :position])
  end
end
