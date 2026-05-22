defmodule NervesSprinklers.Repo.Migrations.CreateScheduleSnapshots do
  use Ecto.Migration

  def change do
    create table(:schedule_snapshots) do
      add :schedule_id, references(:schedules, on_delete: :delete_all), null: false
      add :version, :integer, null: false
      add :snapshot_json, :string, null: false

      timestamps()
    end
  end
end
