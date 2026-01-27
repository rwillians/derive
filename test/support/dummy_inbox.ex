defmodule Dummy.Inbox do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Query

  alias __MODULE__

  @primary_key {:id, :id, autogenerate: true}
  schema "dummy_inbox" do
    field :type, Ecto.Enum, values: [:user_created, :user_email_updated, :user_deleted]
    field :payload, :map
    field :timestamp, :utc_datetime_usec
  end

  @doc false
  def query(filters \\ []) do
    Enum.reduce(filters, Inbox, fn
      {:after, position}, query -> where(query, [event], event.id > ^position)
      {:take, n}, query -> limit(query, ^n)
      {filter, _}, _ -> raise("unsupported filter #{inspect(filter)}")
    end)
  end
end
