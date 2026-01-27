import Config

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# ECTO                                                              #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

config :derive, ecto_repos: [Dummy.Repo]

config :derive, Dummy.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  force_drop: true
