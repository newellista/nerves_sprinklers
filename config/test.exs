import Config

config :nerves_sprinklers,
  role: :coordinator,
  node_name: :sprinklers@localhost,
  timezone: "America/Chicago",
  ecto_repos: [NervesSprinklers.Repo]

config :nerves_sprinklers, NervesSprinklers.Repo,
  database: Path.expand("../priv/test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :ecto, repos: [NervesSprinklers.Repo]

config :nerves_sprinklers, NervesSprinklersWeb.Endpoint,
  http: [port: 4001],
  secret_key_base: "test_secret_key_base_at_least_64_chars_long_xxxxxxxxxxxxxxxxxxxxxxxxxxx",
  live_view: [signing_salt: "test_live_salt"],
  server: false

config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       "nerves_fw_active" => "a",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0"
     }}
