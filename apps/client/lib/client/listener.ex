defmodule Client.Listener do
  @moduledoc """
  监听方
  """

  require Logger
  use GenServer

  @port Application.get_env(:client, :local_port)

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:ok, socket} = :gen_tcp.listen(@port, [:binary, active: false, reuseaddr: true])
    send(self(), :accept)

    Logger.info("Accepting connection on port #{@port}...")
    {:ok, %{socket: socket}}
  end

  def handle_info(:accept, %{socket: socket} = state) do
    {:ok, sock} = :gen_tcp.accept(socket)

    # 从连接池中拿出一个资源
    pid1 = :poolboy.checkout(:worker)

    # 启动一个本地数据处理进程
    {:ok, pid2} = Client.LocalWorker.start(pid1, sock)

    :gen_tcp.controlling_process(sock, pid2)

    # 将本地socket 放到远端链接进程state中
    Client.RemoteWorker.bind_socket(pid1, sock)
    send(self(), :accept)
    {:noreply, state}
  end

  # ignore msg
  def handle_info(_, state) do
    {:noreply, state}
  end
end
