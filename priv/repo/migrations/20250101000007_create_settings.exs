defmodule NervesSprinklers.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :password_hash, :string
      add :password_salt, :string

      timestamps()
    end
  end
end
