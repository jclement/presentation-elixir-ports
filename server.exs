Mix.install([
  {:phoenix, "~> 1.8"},
  {:phoenix_live_view, "~> 1.0"},
  {:phoenix_html, "~> 4.0"},
  {:bandit, "~> 1.6"},
  {:jason, "~> 1.4"}
])

defmodule LogStreamer do
  use GenServer

  @moduledoc false
  @topic "logs:execute_sync"
  @max_lines 20

  # Public API
  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def topic, do: @topic
  def get_buffer, do: GenServer.call(__MODULE__, :get_buffer)
  def start, do: GenServer.call(__MODULE__, :start)
  def stop, do: GenServer.call(__MODULE__, :stop)
  def status, do: GenServer.call(__MODULE__, :status)

  # GenServer
  @impl true
  def init(:ok) do
    # Use raw binary mode and accumulate partial lines; spawn_executable doesn't support line packet mode
    state = %{port: nil, buffer: [], acc: ""}
    send(self(), :ensure_started)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_buffer, _from, state) do
    {:reply, state.buffer, state}
  end

  @impl true
  def handle_call(:start, _from, %{port: nil} = state) do
    send(self(), :ensure_started)
    {:reply, :ok, state}
  end

  def handle_call(:start, _from, state), do: {:reply, :ok, state}

  def handle_call(:stop, _from, %{port: nil} = state), do: {:reply, :ok, state}

  def handle_call(:stop, _from, %{port: port} = state) do
    Port.close(port)
    msg = "[execute-sync stopped]"
    broadcast(msg)
    broadcast_status(false)
    new_buffer = [msg | state.buffer] |> Enum.take(@max_lines)
    {:reply, :ok, %{state | port: nil, buffer: new_buffer}}
  end

  def handle_call(:status, _from, state),
    do: {:reply, if(state.port, do: :online, else: :offline), state}

  @impl true
  def handle_info({port, {:data, chunk}}, %{port: port, acc: acc} = state)
      when is_binary(chunk) do
    parts = String.split(acc <> chunk, "\n")

    {complete, rest} =
      case parts do
        [] ->
          {[], acc <> chunk}

        parts ->
          case List.last(parts) do
            "" -> {Enum.drop(parts, -1), ""}
            last -> {Enum.drop(parts, -1), last}
          end
      end

    new_buffer =
      Enum.reduce(complete, state.buffer, fn line, buf ->
        clean = String.trim_trailing(line, "\r")
        broadcast(clean)
        [clean | buf] |> Enum.take(@max_lines)
      end)

    {:noreply, %{state | acc: rest, buffer: new_buffer}}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    msg = "[execute-sync exited with status #{status}]"
    broadcast(msg)
    broadcast_status(false)
    new_buffer = [msg | state.buffer] |> Enum.take(@max_lines)

    # Schedule restart
    Process.send_after(self(), :ensure_started, 1000)

    {:noreply, %{state | buffer: new_buffer, port: nil}}
  end

  @impl true
  def handle_info(:ensure_started, state) do
    msg = "[execute-sync starting]"
    broadcast(msg)
    new_buffer = [msg | state.buffer] |> Enum.take(@max_lines)

    port =
      Port.open({:spawn_executable, "./execute-sync"}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:args, ["s"]}
      ])

    broadcast_status(true)
    {:noreply, %{state | port: port, buffer: new_buffer}}
  end

  defp broadcast(line) do
    Phoenix.PubSub.broadcast(Demo.PubSub, @topic, {:log_line, line})
  end

  defp broadcast_status(online?) do
    Phoenix.PubSub.broadcast(Demo.PubSub, @topic, {:status, online?})
  end
end

defmodule DemoRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Phoenix.Component

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_root_layout, html: {__MODULE__, :root})
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:browser)
    live("/", LogsLive)
  end

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
    	<head>
    		<meta charset="utf-8"/>
    		<meta name="viewport" content="width=device-width, initial-scale=1"/>
    		<title><%= @page_title %></title>
    		<!-- Tailwind CSS -->
    		<script src="https://cdn.tailwindcss.com"></script>
    		<meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    		<script src="/assets/phoenix.js"></script>
    		<script type="module">
    			import { LiveSocket } from "/assets/phoenix_live_view.esm.js";
    			// Initialize Phoenix and LiveView using Phoenix.Socket from UMD global (phoenix.js)
    			const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
    			const liveSocket = new LiveSocket("/live", window.Phoenix.Socket, { params: { _csrf_token: csrfToken } });
    			liveSocket.connect();
    			window.liveSocket = liveSocket;
    		</script>
    	</head>
    	<body class="bg-gradient-to-br from-purple-500 to-pink-500 min-h-screen flex items-center justify-center">
    		<div class="bg-white/90 backdrop-blur-sm rounded-2xl shadow-2xl p-8">
    			<%= @inner_content %>
    		</div>
    	</body>
    </html>
    """
  end
end

defmodule LogsLive do
  use Phoenix.LiveView
  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Demo.PubSub, LogStreamer.topic())
    end

    {:ok,
     socket
     |> assign(:page_title, "Logs")
     |> assign(:lines, LogStreamer.get_buffer())
     |> assign(:online, LogStreamer.status() == :online)}
  end

  @impl true
  def handle_info({:log_line, line}, socket) do
    lines = [line | socket.assigns.lines] |> Enum.take(20)
    {:noreply, assign(socket, :lines, lines)}
  end

  def handle_info({:status, online?}, socket) do
    {:noreply, assign(socket, :online, online?)}
  end

  @impl true
  def handle_event("start", _params, socket) do
    :ok = LogStreamer.start()
    {:noreply, socket}
  end

  def handle_event("stop", _params, socket) do
    :ok = LogStreamer.stop()
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl w-full">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">execute-sync logs</h1>
          <span class={"inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold " <> if(@online, do: "bg-green-100 text-green-800", else: "bg-gray-200 text-gray-700")}>
            <span class={"mr-1 h-2 w-2 rounded-full " <> if(@online, do: "bg-green-500", else: "bg-gray-400")}></span>
            <%= if @online, do: "Online", else: "Offline" %>
          </span>
        </div>
        <div class="flex items-center gap-2">
          <button phx-click="start" class="px-3 py-1.5 rounded-md text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 disabled:opacity-40" disabled={@online}>
            Start
          </button>
          <button phx-click="stop" class="px-3 py-1.5 rounded-md text-sm font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-40" disabled={!@online}>
            Stop
          </button>
        </div>
      </div>
      <div class="bg-black text-green-300 font-mono text-sm rounded-lg p-4 h-[70vh] overflow-auto">
        <%= for line <- @lines do %>
          <div class="whitespace-pre-wrap break-words"><%= line %></div>
        <% end %>
      </div>
    </div>
    """
  end
end

defmodule DemoEndpoint do
  use Phoenix.Endpoint, otp_app: :demo

  @session_signing_salt System.get_env("SESSION_SIGNING_SALT") ||
                          Base.encode64(:crypto.strong_rand_bytes(32))
  @session_cookie_key System.get_env("SESSION_COOKIE_KEY") || "_sess_demo"
  @session_options [
    store: :cookie,
    key: @session_cookie_key,
    signing_salt: @session_signing_salt
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve Phoenix and LiveView JS directly from the dependency priv/static folders
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
  plug(DemoRouter)
end

defmodule DemoErrorHTML do
  use Phoenix.Component

  def render(_template, assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
    	<head>
    		<meta charset="utf-8"/>
    		<title>Not Found</title>
    		<script src="https://cdn.tailwindcss.com"></script>
    	</head>
    	<body class="min-h-screen flex items-center justify-center bg-gray-50">
    		<div class="text-center text-gray-700">
    			<div class="text-6xl font-bold mb-4"><%= @status %></div>
    			<p class="mb-6">Oh no.  It's broken.</p>
    			<a href="/" class="text-indigo-600 hover:underline">Go home</a>
    		</div>
    	</body>
    </html>
    """
  end
end

# Configure and start
secret_key_base =
  System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(64))

signing_salt = System.get_env("SIGNING_SALT") || Base.encode64(:crypto.strong_rand_bytes(32))

Application.put_env(:demo, DemoEndpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: secret_key_base,
  live_view: [signing_salt: signing_salt],
  pubsub_server: Demo.PubSub,
  render_errors: [formats: [html: DemoErrorHTML], layout: false],
  server: true
)

{:ok, _} =
  Supervisor.start_link(
    [
      {Phoenix.PubSub, name: Demo.PubSub},
      LogStreamer,
      DemoEndpoint
    ],
    strategy: :one_for_one
  )

Process.sleep(:infinity)
