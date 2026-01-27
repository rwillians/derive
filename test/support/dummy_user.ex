defmodule Dummy.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Query

  alias __MODULE__

  @primary_key {:id, Ecto.UUID, []}
  schema "dummy_users" do
    field :name, :string
    field :email, :string
    field :inserted_at, :utc_datetime_usec
    field :updated_at, :utc_datetime_usec
  end

  @doc false
  def query(filters \\ []) do
    Enum.reduce(filters, User, fn
      {:id, id}, query -> where(query, [u], u.id == ^id)
      {filter, _}, _ -> raise("unsupported filter #{inspect(filter)}")
    end)
  end
end
