defmodule Chitchats do
  use Application
  require Logger

  def start(_type, port: port) do
    import Supervisor.Spec, warn: false

    children = [
      worker(GenEvent, [[name: Chitchats.EventManager]]),
      worker(Chitchats.Server, [Chitchats.EventManager, [name: Chitchats.ChatServer]]),
      supervisor(Task.Supervisor, [[name: Chitchats.TaskSupervisor]]),
      worker(Task, [Chitchats, :accept, [port]])
    ]

    opts = [strategy: :one_for_one, name: Chitchats.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [
      :binary, packet: :line, active: false, reuseaddr: true
    ])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Chitchats.TaskSupervisor, fn ->
      Logger.metadata(ip: ip(client))
      Logger.debug "Connection open"
      try do
        Chitchats.ClientHandler.handle(client)
      catch
        :exit, :normal -> Logger.debug "Connection closed"
      end
    end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp ip(socket) do
    {:ok, {ip, _}} = :inet.peername(socket)
    ip |> Tuple.to_list |> Enum.join(".")
  end
end
