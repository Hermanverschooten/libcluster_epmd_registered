defmodule Cluster.Strategy.EpmdRegistered do
  @moduledoc """
  A libcluster strategy for blue/green topologies where several partner node
  names share a single host but only one is ever alive at a time.

  It behaves like `Cluster.Strategy.Epmd` — connecting to a static list of
  `:hosts` and periodically reconnecting after `:timeout` milliseconds — but
  before attempting a connection it asks each host's epmd which node names are
  actually registered and only connects to those.

  This avoids the wasted connection attempts and the "unable to connect"
  warning that stock `Epmd` logs on every tick for the inactive slot of each
  blue/green pair, while still healing the cluster within one `:timeout`
  interval after a deploy flips a slot.

  ## Options

    * `:hosts` — the full list of partner nodes, exactly as with
      `Cluster.Strategy.Epmd`. Multiple apps may share a host; each node name
      is resolved independently.
    * `:timeout` — reconnect interval in milliseconds. Defaults to `5_000`.
      Unlike stock `Epmd` (which defaults to `:infinity`, connecting only at
      startup), periodic reconnection is the whole point of this strategy.

  ## Example

      config :my_app,
        topology: [
          example: [
            strategy: #{inspect(__MODULE__)},
            config: [
              timeout: 5_000,
              hosts: [
                :"my_app_blue@api.example.com",
                :"my_app_green@api.example.com"
              ]
            ]
          ]
        ]
  """
  use GenServer

  alias Cluster.Strategy
  alias Cluster.Strategy.State

  use Strategy

  @default_timeout 5_000

  @typedoc "Resolves a host to the node names registered in its epmd."
  @type resolver :: (charlist() -> {:ok, [{charlist(), non_neg_integer()}]} | {:error, term()})

  @impl true
  def start_link([%State{config: config} = state]) do
    case Keyword.get(config, :hosts, []) do
      [] -> :ignore
      nodes when is_list(nodes) -> GenServer.start_link(__MODULE__, [state])
    end
  end

  @impl true
  def init([state]) do
    connect_registered(state)
    {:ok, state, timeout(state)}
  end

  @impl true
  def handle_info(:timeout, state), do: handle_info(:connect, state)

  def handle_info(:connect, state) do
    connect_registered(state)
    {:noreply, state, timeout(state)}
  end

  def handle_info(_, state), do: {:noreply, state, timeout(state)}

  @doc """
  Filters `hosts` down to the node names currently registered in epmd.

  `resolver` is `&:erl_epmd.names/1` in production and is injectable so the
  grouping/filtering logic can be tested without a running epmd.
  """
  @spec registered_nodes([node()], resolver()) :: [node()]
  def registered_nodes(hosts, resolver) do
    hosts
    |> Enum.group_by(&host_part/1)
    |> Enum.flat_map(fn {host, candidates} ->
      registered = registered_names(host, resolver)
      Enum.filter(candidates, fn node -> name_part(node) in registered end)
    end)
  end

  defp connect_registered(%State{config: config} = state) do
    hosts = Keyword.get(config, :hosts, [])
    nodes = registered_nodes(hosts, &:erl_epmd.names/1)
    Strategy.connect_nodes(state.topology, state.connect, state.list_nodes, nodes)
    state
  end

  defp registered_names(host, resolver) do
    case resolver.(to_charlist(host)) do
      {:ok, names} -> Enum.map(names, fn {name, _port} -> List.to_string(name) end)
      _ -> []
    end
  end

  defp timeout(%State{config: config}), do: Keyword.get(config, :timeout, @default_timeout)

  defp name_part(node), do: node |> Atom.to_string() |> String.split("@") |> hd()
  defp host_part(node), do: node |> Atom.to_string() |> String.split("@") |> List.last()
end
