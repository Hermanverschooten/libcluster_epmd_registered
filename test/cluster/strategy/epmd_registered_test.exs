defmodule Cluster.Strategy.EpmdRegisteredTest do
  use ExUnit.Case, async: true

  alias Cluster.Strategy.EpmdRegistered

  @hosts [
    :"app_blue@api.example.com",
    :"app_green@api.example.com",
    :"web_blue@web.example.com",
    :"web_green@web.example.com"
  ]

  defp resolver(registered) do
    fn host ->
      case Map.fetch(registered, to_string(host)) do
        {:ok, names} -> {:ok, Enum.map(names, &{to_charlist(&1), 4369})}
        :error -> {:error, :nxdomain}
      end
    end
  end

  test "keeps only the slot registered in each host's epmd" do
    resolver =
      resolver(%{
        "api.example.com" => ["app_blue"],
        "web.example.com" => ["web_green"]
      })

    assert EpmdRegistered.registered_nodes(@hosts, resolver) == [
             :"app_blue@api.example.com",
             :"web_green@web.example.com"
           ]
  end

  test "drops all candidates for a host whose epmd is unreachable" do
    resolver = resolver(%{"api.example.com" => ["app_blue"]})

    assert EpmdRegistered.registered_nodes(@hosts, resolver) == [
             :"app_blue@api.example.com"
           ]
  end

  test "returns both slots during a blue/green overlap window" do
    resolver = resolver(%{"api.example.com" => ["app_blue", "app_green"]})

    assert EpmdRegistered.registered_nodes(
             [:"app_blue@api.example.com", :"app_green@api.example.com"],
             resolver
           ) == [
             :"app_blue@api.example.com",
             :"app_green@api.example.com"
           ]
  end

  test "keeps multiple apps co-located on the same host" do
    resolver = resolver(%{"api.example.com" => ["app_blue", "worker_green"]})

    assert EpmdRegistered.registered_nodes(
             [
               :"app_blue@api.example.com",
               :"app_green@api.example.com",
               :"worker_blue@api.example.com",
               :"worker_green@api.example.com"
             ],
             resolver
           ) == [
             :"app_blue@api.example.com",
             :"worker_green@api.example.com"
           ]
  end

  test "ignores names registered in epmd that are not partners" do
    resolver = resolver(%{"api.example.com" => ["app_blue", "some_other_app"]})

    assert EpmdRegistered.registered_nodes(
             [:"app_blue@api.example.com"],
             resolver
           ) == [:"app_blue@api.example.com"]
  end
end
