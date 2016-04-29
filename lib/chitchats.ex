defmodule Chitchats do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Task.Supervisor, [[name: Chitchats.TaskSupervisor]]),
      worker(Task, [Chitchats, :accept, [4574]])
    ]

    opts = [strategy: :one_for_one, name: Chitchats.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info "Connected: #{inspect(client)}"
    {:ok, pid} = Task.Supervisor.start_child(Chitchats.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()
    |> write_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    Logger.info "Received: #{inspect data}"
    data
  end

  defp write_line(line, socket) do
    Logger.info "Sending: #{inspect line}"
    :gen_tcp.send(socket, line)
  end
end
