defmodule NervesSprinklers.Repo do
  use Ecto.Repo,
    otp_app: :nerves_sprinklers,
    adapter: Ecto.Adapters.SQLite3
end
