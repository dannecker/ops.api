defmodule OPS.DeclarationAPI do
  @moduledoc """
  The boundary for the DeclarationAPI system
  """

  import Ecto.{Query, Changeset}, warn: false
  alias OPS.Repo

  alias OPS.Declaration

  def list_declarations(params) when map_size(params) == 0 do
    query = from d in Declaration,
      order_by: [desc: :inserted_at]

    {:ok, Repo.all(query)}
  end

  def list_declarations(params) do
    changeset = declaration_search_changeset(%Declaration{}, params)

    if changeset.valid? do
      query = from d in Declaration,
        where: ^Map.to_list(changeset.changes),
        order_by: [desc: :inserted_at]

      {:ok, Repo.all(query)}
    else
      changeset
    end
  end

  def get_declaration!(id), do: Repo.get!(Declaration, id)

  def create_declaration(attrs \\ %{}) do
    %Declaration{}
    |> declaration_changeset(attrs)
    |> ChangeLogger.insert("declaration", Map.get(attrs, :created_by))
  end

  def update_declaration(%Declaration{} = declaration, attrs) do
    declaration
    |> declaration_changeset(attrs)
    |> ChangeLogger.update("declaration", Map.get(attrs, :updated_by))
  end

  def delete_declaration(%Declaration{} = declaration) do
    Repo.delete(declaration)
  end

  def change_declaration(%Declaration{} = declaration) do
    declaration_changeset(declaration, %{})
  end

  defp declaration_changeset(%Declaration{} = declaration, attrs) do
    fields = ~W(
      declaration_signed_id
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
    )

    required_fields = [
      :declaration_signed_id,
      :employee_id,
      :person_id,
      :start_date,
      :end_date,
      :status,
      :signed_at,
      :created_by,
      :updated_by,
      :is_active,
      :scope,
      :division_id,
      :legal_entity_id,
    ]

    declaration
    |> cast(attrs, fields)
    |> validate_required(required_fields)
    |> validate_inclusion(:scope, ["family_doctor"])
    |> validate_inclusion(:status, ["active", "closed"])
  end

  defp declaration_search_changeset(%Declaration{} = declaration, attrs) do
    fields = [
      :person_id,
      :is_active,
      :employee_id,
    ]

    declaration
    |> cast(attrs, fields)
    |> validate_any_is_present(fields)
  end

  defp validate_any_is_present(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(changeset, hd(fields), "No search fields were specified correctly")
    end
  end

  defp present?(changeset, field) do
    case fetch_change(changeset, field) do
      :error -> false
      {:ok, ""} -> false
      {:ok, _} -> true
    end
  end
end
