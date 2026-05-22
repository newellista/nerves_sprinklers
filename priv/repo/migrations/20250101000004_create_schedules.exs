defmodule NervesSprinklers.Repo.Migrations.CreateSchedules do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :recurrence_type, :string, null: false
      add :recurrence_days, :integer
      add :recurrence_dow, :string
      add :start_date, :date, null: false
      add :start_time, :time, null: false
      add :seasonal_offset, :integer, null: false, default: 100
      add :paused_until, :date

      timestamps()
    end
  end
end
