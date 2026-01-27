defmodule Derive.Repo.Migrations.CreateDeriveTables do
  use Derive.Migration

  def up do
    Derive.Migration.up(1)
  end

  def down do
    Derive.Migration.down(1)
  end
end
