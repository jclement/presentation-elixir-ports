#!/usr/bin/env elixir

defmodule LinePortServer do
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

    {:ok, %{accumulator: ""}}
  end

  @impl true
  def handle_info({_port, {:data, chunk}}, state) do
    # Combine with any leftover data from previous chunk
    data = state.accumulator <> chunk

    # Split on newlines
    parts = String.split(data, "\n")

    # Separate complete lines from potential partial line at end
    {lines, new_accumulator} =
      case List.last(parts) do
        # Ended with newline
        "" -> {Enum.drop(parts, -1), ""}
        # Partial line at end
        partial -> {Enum.drop(parts, -1), partial}
      end

    # Print each complete line
    Enum.each(lines, fn line ->
      clean = String.trim_trailing(line, "\r")
      IO.puts("LINE: #{clean}")
    end)

    {:noreply, %{state | accumulator: new_accumulator}}
  end
end

# Run it
{:ok, _pid} = LinePortServer.start_link()
Process.sleep(:infinity)
