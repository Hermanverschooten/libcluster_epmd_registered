# libcluster_epmd_registered

A [libcluster](https://github.com/bitwalker/libcluster) strategy for blue/green
topologies where several partner node names share a single host but only one is
ever alive at a time.

## The problem

With a blue/green deployment, a host runs two release slots — e.g.
`my_app_blue@api.example.com` and `my_app_green@api.example.com` — but only one
is active at any moment. Listing both in `Cluster.Strategy.Epmd` with a
`:timeout` means libcluster tries to connect to the dormant slot on every tick,
which:

- wastes an epmd round-trip per dead slot, and
- logs an `"unable to connect to ..."` warning every interval — forever.

## The fix

`Cluster.Strategy.EpmdRegistered` is a drop-in replacement. Before attempting a
connection it asks each host's epmd (`:erl_epmd.names/1`) which node names are
actually registered, and only connects to those. No dead slot is ever
attempted, so there is no wasted work and no log spam — while a deploy that
flips a slot still heals the cluster within one `:timeout` interval.

Multiple apps may share a host; each node name is resolved independently.

## Installation

Add it as a git dependency:

```elixir
def deps do
  [
    {:libcluster, "~> 3.3"},
    {:libcluster_epmd_registered,
     git: "https://github.com/Hermanverschooten/libcluster_epmd_registered.git", tag: "v0.1.0"}
  ]
end
```

## Usage

Configure it exactly like `Cluster.Strategy.Epmd`, swapping the strategy module:

```elixir
config :my_app,
  topology: [
    example: [
      strategy: Cluster.Strategy.EpmdRegistered,
      config: [
        timeout: 5_000,
        hosts: [
          :"my_app_blue@api.example.com",
          :"my_app_green@api.example.com"
        ]
      ]
    ]
  ]
```

### Options

| Option     | Default   | Description                                                                 |
| ---------- | --------- | --------------------------------------------------------------------------- |
| `:hosts`   | `[]`      | Full list of partner nodes, as with `Cluster.Strategy.Epmd`.                |
| `:timeout` | `5_000`   | Reconnect interval in milliseconds. Periodic reconnection is always on.     |

## License

MIT
