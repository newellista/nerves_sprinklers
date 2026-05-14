defmodule NervesSprinklersWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :nerves_sprinklers

  @session_options [
    store: :cookie,
    key: "_nerves_sprinklers_key",
    signing_salt: "sprinklers_salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :nerves_sprinklers,
    gzip: false,
    only: NervesSprinklersWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug NervesSprinklersWeb.Router
end
