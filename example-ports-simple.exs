#!/usr/bin/env elixir

defmodule SimplePortServer do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    IO.puts("[Starting: ./execute-sync s]")

    Port.open({:spawn_executable, "./execute-sync"}, [
      :binary,
      :stderr_to_stdout,
      {:args, ["s"]}
    ])

    {:ok, %{}}
  end

  @impl true
  def handle_info({_port, {:data, chunk}}, state) do
    IO.puts("CHUNK: #{inspect(chunk)}")
    {:noreply, state}
  end
end

# Run it
{:ok, _pid} = SimplePortServer.start_link()
Process.sleep(:infinity)