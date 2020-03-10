defmodule Server do
  @moduledoc """
  Documentation for `Server`.
  """

  def start(_type, _args) do
    children = [
      Server.Listener,
      Server.DnsCache
    ]

    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
