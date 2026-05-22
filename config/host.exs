import Config

# Host role config — coordinator by default for local dev
config :nerves_sprinklers,
  role: :coordinator,
  node_name: :sprinklers@localhost,
  timezone: "America/Chicago",
  ecto_repos: [NervesSprinklers.Repo],
  auth_settings_file: Path.expand("../sprinklers_auth_dev.dat", __DIR__)

config :nerves_sprinklers, NervesSprinklersWeb.Endpoint,
  http: [port: 4000],
  secret_key_base: "dev_secret_key_base_at_least_64_chars_long_xxxxxxxxxxxxxxxxxxxxxxxxxxx",
  live_view: [signing_salt: "dev_live_salt"],
  server: true,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:nerves_sprinklers, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:nerves_sprinklers, ~w(--watch)]}
  ]

config :nerves_sprinklers, NervesSprinklers.Repo,
  database: Path.expand("../sprinklers_dev.db", __DIR__),
  pool_size: 5

config :ecto, repos: [NervesSprinklers.Repo]

config :esbuild,
  version: "0.17.11",
  nerves_sprinklers: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  nerves_sprinklers: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       # The KV store on Nerves systems is typically read from UBoot-env, but
       # this allows us to use a pre-populated InMemory store when running on
       # host for development and testing.
       #
       # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
       # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata

       "nerves_fw_active" => "a",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0"
     }}
