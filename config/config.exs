use Mix.Config

config :logger, level: :info

config :kernel,
  net_ticktime: 10,
  dist_auto_connect: :never
