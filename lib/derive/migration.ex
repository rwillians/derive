defmodule Derive.Migration do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  import Derive.Utils, only: [merge_blocks: 2]

  #
  #   ↓ BEHAVIOUR API
  #

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback up() :: term

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback down() :: term

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  defmacro __using__(_) do
    quote do
      use Ecto.Migration
    end
  end

  @empty_block {:__block__, [], []}

  @doc ~S"""
  @todo add documentation, make sure to cover the points below

  Key points:
  * sequentially runs all migrations up to the given `n`th version.
  """
  @doc since: "0.1.0"

  defmacro up(n) when is_integer(n) and n > 0 do
    1..n//+1
    |> Enum.map(&run(up: &1))
    |> Enum.reduce(@empty_block, &merge_blocks/2)
  end

  @doc ~S"""
  @todo add documentation, make sure to cover the points below

  Key points:
  * sequentially rolls back all migrations down to the given `n`th version.
  """
  @doc since: "0.1.0"

  defmacro down(n) when is_integer(n) and n > 0 do
    n..1//-1
    |> Enum.map(&run(down: &1))
    |> Enum.reduce(@empty_block, &merge_blocks/2)
  end

  #
  #   ↓ ACTUAL MIGRATIONS, BY VERSION NUMBER (KEEP IT SORTED!)
  #

  defp run(up: 1) do
    quote do
      create table(:derive_cursors, primary_key: false) do
        add :consumer_id, :string, size: 96, primary_key: true
        add :position, :integer, null: false
        add :last_synced_at, :utc_datetime_usec
        add :stuck_since, :utc_datetime_usec
        add :stuck_reason, :string
      end
    end
  end

  defp run(down: 1) do
    quote do
      drop_if_exists table(:derive_cursors)
    end
  end
end
