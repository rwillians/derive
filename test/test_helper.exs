ExUnit.start()

# #
# derive doesn't have an `Application` to start the Repo from,
# therefore we need to manually start it for tests only
{:ok, _} = Dummy.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(Dummy.Repo, :manual)
