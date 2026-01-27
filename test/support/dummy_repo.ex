defmodule Dummy.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :derive,
    adapter: Ecto.Adapters.Postgres
end
