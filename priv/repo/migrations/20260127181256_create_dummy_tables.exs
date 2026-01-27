defmodule Derive.Repo.Migrations.CreateDummyTables do
  use Ecto.Migration

  def change do
    create table(:dummy_inbox) do
      add :type, :string, null: false
      add :payload, :json, null: false
      add :timestamp, :utc_datetime_usec, null: false
    end

    create table(:dummy_users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end
  end
end
