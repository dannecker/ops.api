defmodule OPS.Declarations do
  @moduledoc """
  The boundary for the Declarations system
  """

  use OPS.Search
  import Ecto.{Query, Changeset}, warn: false
  alias Ecto.Multi
  alias OPS.Repo

  alias OPS.AuditLogs
  alias OPS.Declarations.Declaration
  alias OPS.Declarations.DeclarationSearch

  def list_declarations(params) do
    %DeclarationSearch{}
    |> declaration_changeset(params)
    |> search(params, Declaration, 50)
  end

  def get_declaration!(id), do: Repo.get!(Declaration, id)

  # TODO: Make more clearly getting created_by and updated_by parameters
  def create_declaration(attrs \\ %{}) do
    %Declaration{}
    |> declaration_changeset(attrs)
    |> Repo.insert_and_log(Map.get(attrs, "created_by", Map.get(attrs, :created_by)))
  end

  def update_declaration(%Declaration{} = declaration, attrs) do
    declaration
    |> declaration_changeset(attrs)
    |> Repo.update_and_log(Map.get(attrs, "updated_by", Map.get(attrs, :updated_by)))
  end

  def delete_declaration(%Declaration{} = declaration) do
    Repo.delete(declaration)
  end

  def change_declaration(%Declaration{} = declaration) do
    declaration_changeset(declaration, %{})
  end

  defp declaration_changeset(%Declaration{} = declaration, attrs) do
    fields = ~W(
      id
      employee_id
      person_id
      start_date
      end_date
      status
      signed_at
      created_by
      updated_by
      is_active
      scope
      division_id
      legal_entity_id
      declaration_request_id
      seed
    )a

    declaration
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_status_transition()
    |> validate_inclusion(:scope, ["family_doctor"])
    |> validate_inclusion(:status, Enum.map(
      ~w(
        active
        closed
        terminated
        rejected
        pending
      )a,
      &Declaration.status/1
    ))
  end

  defp declaration_changeset(%DeclarationSearch{} = declaration, attrs) do
    fields = DeclarationSearch.__schema__(:fields)

    cast(declaration, attrs, fields)
  end

  def create_declaration_with_termination_logic(%{"person_id" => person_id} = declaration_params) do
    query = Declaration
      |> where([d], d.person_id == ^person_id)
      |> where([d], d.status in ^[Declaration.status(:active), Declaration.status(:pending)])

    user_id = Map.get(declaration_params, "created_by")
    updates = [status: Declaration.status(:terminated), updated_by: user_id, updated_at: DateTime.utc_now()]

    Multi.new()
    |> Multi.update_all(:previous_declarations, query, [set: updates], returning: [:id])
    |> Multi.insert(:new_declaration, declaration_changeset(%Declaration{}, declaration_params))
    |> Multi.run(:logged_terminations, fn multi -> log_updates(user_id, multi.previous_declarations, updates) end)
    |> Repo.transaction()
  end

  def approve_declarations(value, unit) do
    query =
      Declaration
      |> where([d], fragment("?::date < now()::date", datetime_add(d.inserted_at, ^value, ^unit)))
      |> where([d], d.status == ^Declaration.status(:pending))

    user_id = Confex.get_env(:ops, :declaration_terminator_user)
    updates = [status: Declaration.status(:active), updated_by: user_id, updated_at: DateTime.utc_now()]

    Multi.new()
    |> Multi.update_all(:declarations, query, [set: updates], returning: [:id])
    |> Multi.run(:logged_declarations, fn multi -> log_updates(user_id, multi.declarations, updates) end)
    |> Repo.transaction()
  end

  def terminate_declarations do
    query =
      Declaration
      |> where([d], fragment("?::date < now()::date", d.end_date))
      |> where([d], not d.status in ^[Declaration.status(:closed), Declaration.status(:terminated)])

    user_id = Confex.get_env(:ops, :declaration_terminator_user)
    updates = [status: Declaration.status(:closed), updated_by: user_id, updated_at: DateTime.utc_now()]

    Multi.new()
    |> Multi.update_all(:declarations, query, [set: updates], returning: [:id])
    |> Multi.run(:logged_terminations, fn multi -> log_updates(user_id, multi.declarations, updates) end)
    |> Repo.transaction()
  end
  def terminate_declarations(user_id, employee_id) do
    query =
      Declaration
      |> where([d], d.status in ^[Declaration.status(:active), Declaration.status(:pending)])
      |> where([d], d.employee_id == ^employee_id)

    updates = [status: Declaration.status(:terminated), updated_by: user_id, updated_at: DateTime.utc_now()]

    Multi.new
    |> Multi.update_all(:terminated_declarations, query, [set: updates], returning: [:id])
    |> Multi.run(:logged_terminations, fn multi -> log_updates(user_id, multi.terminated_declarations, updates) end)
    |> Repo.transaction()
  end

  def terminate_person_declarations(user_id, person_id) do
    query = from d in Declaration,
      where: [person_id: ^person_id]

    updates = [status: "terminated", updated_by: user_id, updated_at: DateTime.utc_now()]

    Multi.new
    |> Multi.update_all(:terminated_declarations, query, [set: updates], returning: [:id])
    |> Multi.run(:logged_terminations, fn multi -> log_updates(user_id, multi.terminated_declarations, updates) end)
    |> Repo.transaction()
  end

  def log_updates(user_id, {_, terminated_declarations}, updates) do
    changeset = Enum.into(updates, %{updated_by: user_id})

    updates =
      Enum.reduce terminated_declarations, [], fn declaration, acc ->
        AuditLogs.create_audit_log(%{
          actor_id: user_id,
          resource: "declaration",
          resource_id: declaration.id,
          changeset: changeset
        })

        [declaration.id|acc]
      end

    {:ok, updates}
  end

  def validate_status_transition(changeset) do
    from = changeset.data.status
    {_, to} = fetch_field(changeset, :status)

    valid_transitions = [
      {"active", "terminated"},
      {"active", "closed"},
      {"pending_verification", "active"},
      {"pending_verification", "rejected"}
    ]

    if {from, to} in valid_transitions || is_nil(from) do
      changeset
    else
      add_error(changeset, :status, "Incorrect status transition.")
    end
  end
end
