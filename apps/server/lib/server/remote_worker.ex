defmodule Server.RemoteWorker do
  @moduledoc """
  doc
  """

  require Logger
  use GenServer

  @key Application.get_env(:server, :key)

  def send_message(pid, message), do: GenServer.cast(pid, {:message, message})

  def start(rsock, lsock) do
    GenServer.start(__MODULE__, rsock: rsock, lsock: lsock)
  end

  def init(rsock: rsock, lsock: lsock) do
    Process.send_after(self(), :reset_active, 500)
    {:ok, %{rsock: rsock, lsock: lsock}}
  end

  # 目标服务发来的流量加密转发至client
  def handle_info({:tcp, _socket, data}, state) do
    Logger.info("Send: #{inspect(data)}")
    :gen_tcp.send(state.lsock, Common.Crypto.aes_encrypt(data, @key, base64: false))
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

  def handle_info(:reset_active, state) do
    :inet.setopts(state.rsock, active: 1000)
    Process.send_after(self(), :reset_active, 1000)
    {:noreply, state}
  end

  def handle_cast({:message, message}, state) do
    :ok = :gen_tcp.send(state.rsock, message)
    {:noreply, state}
  end
end
