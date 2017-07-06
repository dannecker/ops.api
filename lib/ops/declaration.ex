defmodule OPS.Declaration do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias OPS.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "declarations" do
    field :employee_id, Ecto.UUID
    field :person_id, Ecto.UUID
    field :start_date, :date
    field :end_date, :date
    field :status, :string
    field :signed_at, :utc_datetime
    field :created_by, Ecto.UUID
    field :updated_by, Ecto.UUID
    field :is_active, :boolean, default: false
    field :scope, :string
    field :division_id, Ecto.UUID
    field :legal_entity_id, Ecto.UUID

    timestamps(type: :utc_datetime)
  end
end
