defmodule Dummy.Consumer do
  @moduledoc false

  use Derive, otp_app: :derive

  alias Dummy.Inbox, as: Event
  alias Dummy.User

  @impl Derive
  def fetch(repo, filters), do: repo.all(Event.query(filters))

  @impl Derive
  def handle_event(%Event{type: :user_created} = event) do
    insert(%User{
      id: event.payload["id"],
      name: event.payload["name"],
      email: event.payload["email"],
      inserted_at: event.timestamp,
      updated_at: event.timestamp
    })
  end

  def handle_event(%Event{type: :user_email_updated} = event) do
    update(User.query(id: event.payload["user_id"]), %{
      email: event.payload["new_email"],
      updated_at: event.timestamp
    })
  end

  def handle_event(%Event{type: :user_deleted} = event) do
    delete(User.query(id: event.payload["user_id"]))
  end
end
