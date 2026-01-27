import Config

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# ECTO                                                              #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case config_env() do
  :test ->
    database_url =
      System.get_env("DATABASE_URL") ||
        "postgres://postgres:postgres@localhost:5432/stated_test"

    config :derive, Dummy.Repo,
      url: database_url,
      pool_size: System.schedulers_online() * 2

  _ ->
    :ok
end
