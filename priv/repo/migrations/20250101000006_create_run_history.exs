defmodule NervesSprinklers.Repo.Migrations.CreateRunHistory do
  use Ecto.Migration

  def change do
    create table(:schedule_runs) do
      add :schedule_id, references(:schedules, on_delete: :nilify_all)
      add :schedule_name, :string, null: false
      add :trigger_type, :string, null: false
      add :scheduled_at, :utc_datetime
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :status, :string, null: false

      timestamps()
    end

    create table(:zone_runs) do
      add :schedule_run_id, references(:schedule_runs, on_delete: :delete_all), null: false
      add :zone_number, :integer, null: false
      add :zone_name, :string, null: false
      add :planned_duration_sec, :integer, null: false
      add :actual_duration_sec, :integer
      add :status, :string, null: false

      timestamps()
    end
  end
end
