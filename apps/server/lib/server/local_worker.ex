defmodule Server.LocalWorker do
  @moduledoc """
  doc
  """
  require Logger
  use GenServer

  @key Application.get_env(:server, :key)
  @connect_succ <<0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>
  @connect_fail <<0x05, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>

  def start(socket), do: GenServer.start(__MODULE__, socket: socket)

  def init(socket: socket) do
    :inet.setopts(socket, active: 500)
    Process.send_after(self(), :reset_active, 1000)
    {:ok, %{socket: socket, pid: nil}}
  end

  # 设置流量限额
  def handle_info(:reset_active, state) do
    :inet.setopts(state.socket, active: 500)
    Process.send_after(self(), :reset_active, 1000)
    {:noreply, state}
  end

  # client流量的处理入口
  def handle_info({:tcp, socket, ciphertext}, state) do
    Logger.info("Receive: #{inspect(ciphertext)}")

    ciphertext
    |> Common.Crypto.aes_decrypt(@key, base64: false)
    |> case do
      # 不鉴权
      <<0x05, 0x01, 0x00>> ->
        encrypt_send(socket, <<0x05, 0x00>>)
        {:noreply, state}

      # 连接的真正的远端ip
      <<0x05, 0x01, 0x00, 0x01, _addr::binary>> = data ->
        data
        |> connect_remote(socket)
        |> (fn
              {:ok, pid} ->
                encrypt_send(socket, @connect_succ)
                {:noreply, %{state | pid: pid}}

              :error ->
                encrypt_send(socket, @connect_fail)
                {:noreply, state}
            end).()

      <<0x05, 0x01, 0x00, 0x03, _addr::binary>> = data ->
        data
        |> connect_remote(socket)
        |> (fn
              {:ok, pid} ->
                encrypt_send(socket, @connect_succ)
                {:noreply, %{state | pid: pid}}

              :error ->
                encrypt_send(socket, @connect_fail)
                {:noreply, state}
            end).()

      # 建立连接后的通信数据
      other ->
        Server.RemoteWorker.send_message(state.pid, other)
        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _}, state) do
    Logger.info("Socket closed")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

  defp encrypt_send(socket, data) do
    Logger.info("Send: #{inspect(data)}")
    :gen_tcp.send(socket, Common.Crypto.aes_encrypt(data, @key, base64: false))
  end

  # ip类型
  defp parse_remote_addr(<<_pre::24, 0x01, ip1, ip2, ip3, ip4, port::16>>),
    do: {{ip1, ip2, ip3, ip4}, port}

  # hostname类型
  defp parse_remote_addr(<<_pre::24, 0x03, len, addr::binary>>) do
    host_size = 8 * len

    hostname = binary_part(addr, 0, len)
    Logger.info("HostName: #{hostname}")

    {:ok, {:hostent, _, _, :inet, 4, [{ip1, ip2, ip3, ip4} | _]}} =
      :inet.gethostbyname(to_charlist(hostname))

    <<_::size(host_size), port::16>> = addr

    {{ip1, ip2, ip3, ip4}, port}
  end

  # 新建一个连接真实服务的socket
  defp connect_remote(data, socket) do
    with {ipaddr, port} <- parse_remote_addr(data),
         {:ok, rsock} <- :gen_tcp.connect(ipaddr, port, [:binary, active: 500]),
         {:ok, pid} <- Server.RemoteWorker.start(rsock, socket) do
      Logger.info("Connect to #{inspect(ipaddr)}")
      :gen_tcp.controlling_process(rsock, pid)
      {:ok, pid}
    else
      _ ->
        :error
    end
  end
end
