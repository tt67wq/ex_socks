defmodule Client do
  @moduledoc """
  Documentation for `Client`.
  """

  defp poolboy_config do
    [
      name: {:local, :worker},
      worker_module: Client.RemoteWorker,
      size: 30,
      max_overflow: 10
    ]
  end

  def start(_type, _args) do
    children = [
      Client.Listener,
      :poolboy.child_spec(:worker, poolboy_config())
    ]

    opts = [strategy: :one_for_one, name: Client.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
