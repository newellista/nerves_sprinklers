defmodule NervesSprinklers.Repo.Migrations.CreateZones do
  use Ecto.Migration

  def change do
    create table(:zones) do
      add :number, :integer, null: false
      add :name, :string, null: false
      add :node, :string, null: false
      add :gpio_pin, :integer, null: false
      add :active_low, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:zones, [:number])
  end
end
