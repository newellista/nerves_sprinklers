defmodule NervesSprinklers.Schema.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field(:password_hash, :string)
    field(:password_salt, :string)

    timestamps()
  end

  def password_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:password_hash, :password_salt])
    |> validate_required([:password_hash, :password_salt])
  end
end
