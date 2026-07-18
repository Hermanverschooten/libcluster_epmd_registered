defmodule ClusterEpmdRegistered.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/Hermanverschooten/libcluster_epmd_registered"

  def project do
    [
      app: :libcluster_epmd_registered,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:libcluster, "~> 3.3"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A libcluster Epmd strategy that only connects to node names currently " <>
      "registered in each host's epmd — built for blue/green topologies where " <>
      "several node names share a host but only one is alive at a time."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
