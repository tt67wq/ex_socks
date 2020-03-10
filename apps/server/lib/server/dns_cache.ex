defmodule Server.DnsCache do
  @moduledoc """
  本地ETS缓存


  ## Config example
  ```
  config :my_app, :cache,
    name: :cache
  ```

  ## Usage:
  ```
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {EtsCache, Application.get_env(:my_app, :cache)},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

  """
  use GenServer
  require Logger

  @table_name :dns_cache
  @beat_delta 1000

  @doc """
  获取ip地址
  """
  def get_addr(<<_pre::24, 0x01, ip1, ip2, ip3, ip4, port::16>>),
    do: {{ip1, ip2, ip3, ip4}, port}

  def get_addr(<<_pre::24, 0x03, len, addr::binary>>) do
    host_size = 8 * len
    <<_::size(host_size), port::16>> = addr

    hostname = binary_part(addr, 0, len)
    Logger.info("HostName: #{hostname}")

    @table_name
    |> get(hostname)
    |> (fn
          {:ok, nil} ->
            hostname
            |> gethostbyname()
            |> (fn
                  {:ok, ip} ->
                    put(@table_name, hostname, ip, 300)
                    {ip, port}

                  :error ->
                    :error
                end).()

          {:ok, ip} ->
            {ip, port}
        end).()
  end

  def get_addr(data) do
    Logger.error("Cannot parse ip from #{inspect(data)}")
    :error
  end

  defp gethostbyname(hostname) do
    hostname
    |> to_charlist()
    |> :inet.gethostbyname()
    |> (fn
          {:ok, {:hostent, _, _, :inet, 4, [{ip1, ip2, ip3, ip4} | _]}} ->
            {:ok, {ip1, ip2, ip3, ip4}}

          _ ->
            :error
        end).()
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  add a new cache key/value

  * `name` - cache service name, genserver name
  * `key`  - key of cache
  * `value` - value of cache
  * `expire` - how many seconds this cache pair can survive 

  ## Examples

  iex> Server.DnsCache.put(:cache, "foo", "bar", 5)
  {:ok, "OK"}
  """
  def put(name, key, value, expire) do
    {:ok, :ets.insert(name, {key, value, timestamp(:seconds) + expire})}
  end

  @doc """
  get cache value by key

  * `name` - cache service name, genserver name
  * `key` - key of cache

  ## Examples

  iex> Server.DnsCache.get(:cache, "foo")
  {:ok, "bar"}
  """
  def get(name, key) do
    case :ets.lookup(name, key) do
      [] -> {:ok, nil}
      [{_, value, _}] -> {:ok, value}
    end
  end

  @doc """
  check if key in cache table

  * `name` - cache service name, genserver name
  * `key` - key of cache

  ## Examples

  iex> Server.DnsCache.exists?(:cache, "foo")
  false
  """
  def exist?(name, key) do
    {:ok, nil} != get(name, key)
  end

  @doc """
  drop a cache pair

  * `name` - cache service name, genserver name
  * `key` - key of cache

  ## Examples

  iex> Server.DnsCache.del(:cache, "foo")
  {:ok, 1}
  """
  def del(name, key) do
    {:ok, :ets.delete(name, key)}
  end

  #### Server
  def init(args) do
    table_name = Keyword.get(args, :table_name, @table_name)

    :ets.new(table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_work(@beat_delta)
    {:ok, %{name: table_name}}
  end

  @doc """
  auto drop the key/value if the timestamp matches
  """
  def handle_info(:work, state) do
    now = timestamp(:seconds)

    state.name
    |> :ets.select([{{:"$1", :_, :"$2"}, [{:<, :"$2", now}], [:"$1"]}])
    |> Enum.map(fn x -> :ets.delete(state.name, x) end)

    schedule_work(@beat_delta)
    {:noreply, state}
  end

  defp schedule_work(time_delta), do: Process.send_after(self(), :work, time_delta)

  def timestamp(typ \\ :seconds), do: :os.system_time(typ)
end
