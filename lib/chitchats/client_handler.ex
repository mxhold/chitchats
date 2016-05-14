defmodule Chitchats.ClientHandler do
  require Logger

  def handle(socket) do
    {:ok, name} = :gen_tcp.recv(socket, 0)
    name = String.strip name
    Logger.info "#{name} joined."

    {:ok, names} = Chitchats.Server.join(Chitchats.ChatServer, name)

    loop_handle(socket, name)
  end

  def loop_handle(socket, name) do
    receive do
      {:join, name} -> :gen_tcp.send(socket, "#{name} joined.\n")
      {:say, name, message} ->
        message = String.strip message
        Logger.info "#{name}: #{message}"
        :gen_tcp.send(socket, "#{name}: #{message}\n.\n")
      {:part, name} -> :gen_tcp.send(socket, "#{name} left.\n")
      _ -> nil
    after 0 -> nil
    end

    case :gen_tcp.recv(socket, 0, 10) do
      {:ok, message} -> Chitchats.Server.say(Chitchats.ChatServer, message)
      {:error, :timeout} -> nil
      {:error, :closed} ->
        Logger.info "#{name} left."
        Chitchats.Server.part(Chitchats.ChatServer)
        exit(:normal)
    end

    loop_handle(socket, name)
  end
end
