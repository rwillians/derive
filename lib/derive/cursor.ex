defmodule Derive.Cursor do
  @moduledoc false
  @moduledoc since: "0.1.0"

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__

  @typedoc false
  @typedoc since: "0.1.0"

  @type t :: %Cursor{
          consumer_id: String.t(),
          position: non_neg_integer,
          last_synced_at: DateTime.t() | nil,
          stuck_since: DateTime.t() | nil,
          stuck_reason: String.t() | nil
        }

  @primary_key {:consumer_id, :string, []}
  schema "derive_cursors" do
    field :position, :integer, default: 0
    field :last_synced_at, :utc_datetime_usec
    field :stuck_since, :utc_datetime_usec
    field :stuck_reason, :string
  end

  @doc false
  @spec changeset(record, params) :: Ecto.Changeset.t()
        when record: t(),
             params: %{atom => term}

  def changeset(%Cursor{} = record \\ %Cursor{}, params) do
    record
    |> cast(params, [:consumer_id, :position, :last_synced_at, :stuck_since, :stuck_reason])
    |> validate_required([:consumer_id, :position])
    |> validate_length(:consumer_id, min: 1, max: 96)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_length(:stuck_reason, min: 1)
  end

  @doc false
  @spec query(filters) :: Ecto.Query.t()
        when filters: keyword | map

  def query(filters \\ []) when is_list(filters) or is_non_struct_map(filters) do
    Enum.reduce(filters, Cursor, fn
      {:consumer_id, mod}, query -> where(query, [c], c.consumer_id == ^mod)
      {filter, _}, _ -> raise("unsupported filter #{inspect(filter)}")
    end)
  end

  @doc false
  @spec resolve!(repo, consumer) :: t
        when repo: Ecto.Repo.t(),
             consumer: module

  def resolve!(repo, consumer) when is_atom(consumer) do
    consumer_id = inspect(consumer)

    with nil <- repo.one(query(consumer_id: consumer_id)),
         do: repo.insert!(changeset(%{consumer_id: consumer_id, position: 0}))
  end
end
