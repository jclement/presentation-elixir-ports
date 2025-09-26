#!/usr/bin/env elixir

Mix.install([
  {:phoenix, "~> 1.8"},
  {:phoenix_live_view, "~> 1.0"},
  {:phoenix_html, "~> 4.0"},
  {:bandit, "~> 1.6"},
  {:jason, "~> 1.4"}
])

defmodule HelloLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(count: 0)
     |> assign(:page_title, "Basic LiveView")}
  end

  def handle_event("inc", _params, socket) do
    socket = update(socket, :count, &(&1 + 1))
    {:noreply, assign(socket, :page_title, "Count: #{socket.assigns.count}")}
  end

  def render(assigns) do
    ~H"""
    <div style="text-align: center; font-family: system-ui;">

      <div style="font-size: 3rem; margin: 2rem 0; font-weight: bold;">
        <%= @count %>
      </div>

      <button phx-click="inc" style="padding: 1rem 2rem; font-size: 1.5rem; background: #10b981; color: white; border: none; border-radius: 8px; cursor: pointer;">
        Click me!
      </button>
    </div>
    """
  end
end

defmodule BasicRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Phoenix.Component

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_root_layout, html: {__MODULE__, :root})
  end

  scope "/" do
    pipe_through(:browser)
    live("/", HelloLive)
  end

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1"/>
      <title><%= @page_title %></title>
      <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
      <script src="/assets/phoenix.js"></script>
      <script type="module">
        import { LiveSocket } from "/assets/phoenix_live_view.esm.js";
        const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
        const liveSocket = new LiveSocket("/live", window.Phoenix.Socket, { params: { _csrf_token: csrfToken } });
        liveSocket.connect();
      </script>
    </head>
    <body style="margin: 0; padding: 2rem; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center;">
      <div style="background: white; padding: 3rem; border-radius: 16px; box-shadow: 0 20px 50px rgba(0,0,0,0.1);">
        <%= @inner_content %>
      </div>
    </body>
    </html>
    """
  end
end

defmodule BasicEndpoint do
  use Phoenix.Endpoint, otp_app: :basic

  @session_options [
    store: :cookie,
    key: "_basic_session",
    signing_salt: Base.encode64(:crypto.strong_rand_bytes(32))
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static,
    at: "/assets",
    from: {:phoenix, "priv/static"},
    only: ~w(phoenix.js)
  )

  plug(Plug.Static,
    at: "/assets",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.esm.js)
  )

  plug(Plug.Session, @session_options)
  plug(BasicRouter)
end

# Configure
Application.put_env(:basic, BasicEndpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [port: 4001],
  secret_key_base: Base.encode64(:crypto.strong_rand_bytes(64)),
  live_view: [signing_salt: Base.encode64(:crypto.strong_rand_bytes(32))],
  server: true
)

# Start
{:ok, _} = Supervisor.start_link([BasicEndpoint], strategy: :one_for_one)

IO.puts("🚀 Basic LiveView server running at http://localhost:4001")
Process.sleep(:infinity)
