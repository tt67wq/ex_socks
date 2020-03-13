defmodule Client.RemoteWorker do
  @moduledoc """
  doc
  """

  require Logger
  use GenServer

  @ip Application.get_env(:client, :remote_host)
  @port Application.get_env(:client, :remote_port)
  @key Application.get_env(:client, :key)

  def send_message(pid, message), do: GenServer.cast(pid, {:message, message})
  def bind_socket(pid, socket), do: GenServer.cast(pid, {:bind, socket})

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{socket: nil, local_socket: nil})
  end

  def init(state) do
    send(self(), :connect)
    {:ok, state}
  end

  def handle_info(:connect, state) do
    Logger.info("Connecting to #{:inet.ntoa(@ip)}:#{@port}")

    case :gen_tcp.connect(@ip, @port, [:binary, active: 500, packet: 2]) do
      {:ok, socket} ->
        Process.send_after(self(), :reset_active, 1000)
        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        disconnect(state, reason)
    end
  end

  # vps发来的流量解密后发给local worker
  def handle_info({:tcp, _socket, data}, state) do
    plaintext = Common.Crypto.aes_decrypt(data, @key, base64: false)
    Logger.debug("Receive: #{inspect(plaintext)}")
    :gen_tcp.send(state.local_socket, plaintext)
    {:noreply, state}
  end

  def handle_info(:reset_active, state) do
    :inet.setopts(state.socket, active: 500)
    Process.send_after(self(), :reset_active, 1000)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

  # 流量加密后发向vps
  def handle_cast({:message, message}, state) do
    Logger.debug("Send: #{inspect(message)}")
    :ok = :gen_tcp.send(state.socket, Common.Crypto.aes_encrypt(message, @key, base64: false))
    {:noreply, state}
  end

  def handle_cast({:bind, socket}, state), do: {:noreply, %{state | local_socket: socket}}

  def disconnect(state, reason) do
    Logger.warn("Disconnected: #{reason}")
    {:stop, :normal, state}
  end
end
