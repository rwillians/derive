import Config

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# ENVIRONMENT SPECIFIC OVERRIDES                                    #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case config_env() do
  :test -> import_config("test.exs")
  _     -> :ok
end
