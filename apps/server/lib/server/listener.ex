defmodule Server.Listener do
  @moduledoc """
  doc
  """

  require Logger
  use GenServer

  @port Application.get_env(:server, :port)

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:ok, socket} = :gen_tcp.listen(@port, [:binary, packet: 2, reuseaddr: true])
    send(self(), :accept)

    Logger.info("Accepting connection on port #{@port}...")
    {:ok, %{socket: socket}}
  end

  def handle_info(:accept, %{socket: socket} = state) do
    {:ok, sock} = :gen_tcp.accept(socket)

    # 启动一个客户端数据处理进程
    {:ok, pid} = Server.LocalWorker.start(sock)
    Logger.info("new client established, #{inspect(pid)}")
    :gen_tcp.controlling_process(sock, pid)
    send(self(), :accept)
    {:noreply, state}
  end
end
