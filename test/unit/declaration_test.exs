defmodule OPS.DeclarationAPITest do
  use OPS.DataCase

  alias OPS.DeclarationAPI
  alias OPS.Declaration

  @create_attrs %{
    "employee_id" => "employee_id",
    "person_id" => "person_id",
    "start_date" => "2016-10-10 00:00:00.000000",
    "end_date" => "2016-12-07 00:00:00.000000",
    "status" => "active",
    "signed_at" => "2016-10-09 23:50:07.000000",
    "created_by" => Ecto.UUID.generate(),
    "updated_by" => Ecto.UUID.generate(),
    "is_active" => true,
    "scope" => "family_doctor",
    "division_id" => Ecto.UUID.generate(),
    "legal_entity_id" => "legal_entity_id",
  }

  @update_attrs %{
    "employee_id" => "updated_employee_id",
    "person_id" => "updated_person_id",
    "start_date" => "2016-10-11 00:00:00.000000",
    "end_date" => "2016-12-08 00:00:00.000000",
    "status" => "closed",
    "signed_at" => "2016-10-10 23:50:07.000000",
    "created_by" => Ecto.UUID.generate(),
    "updated_by" => Ecto.UUID.generate(),
    "is_active" => false,
    "scope" => "family_doctor",
    "division_id" => Ecto.UUID.generate(),
    "legal_entity_id" => "updated_legal_entity_id",
  }

   @invalid_attrs %{
     "division_id" => "invalid"
   }

  def fixture(:declaration, attrs \\ @create_attrs) do
    create_attrs =
      attrs
      |> Map.put("employee_id", Ecto.UUID.generate())
      |> Map.put("legal_entity_id", Ecto.UUID.generate())


    {:ok, declaration} = DeclarationAPI.create_declaration(create_attrs)
    declaration
  end

  test "list_declarations/1 returns all declarations" do
    declaration = fixture(:declaration)
    assert DeclarationAPI.list_declarations(%{}) == {:ok, [declaration]}
  end

  test "get_declaration! returns the declaration with given id" do
    declaration = fixture(:declaration)
    assert DeclarationAPI.get_declaration!(declaration.id) == declaration
  end

  test "create_declaration/1 with valid data creates a declaration" do
    create_attrs =
      @create_attrs
      |> Map.put("employee_id", Ecto.UUID.generate())
      |> Map.put("legal_entity_id", Ecto.UUID.generate())

    assert {:ok, %Declaration{} = declaration} = DeclarationAPI.create_declaration(create_attrs)

    assert declaration.person_id == "person_id"
    assert declaration.start_date
    assert declaration.end_date
    assert declaration.status == "active"
    assert declaration.scope == "family_doctor"
    assert declaration.signed_at
    assert declaration.created_by == create_attrs["created_by"]
    assert declaration.updated_by == create_attrs["updated_by"]
    assert declaration.is_active
    assert declaration.employee_id == create_attrs["employee_id"]
    assert declaration.legal_entity_id == create_attrs["legal_entity_id"]
  end

  @tag pending: true
  test "create_declaration/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = DeclarationAPI.create_declaration(@invalid_attrs)
  end

  describe "create_declaration_with_termination_logic/1" do
    test "with valid data creates declaration and terminates other person declarations" do
      %{id: id1} = fixture(:declaration)
      %{id: id2} = fixture(:declaration, Map.put(@create_attrs, "person_id", "another_person_id"))
      {:ok, %{new_declaration: %{id: id}}} = DeclarationAPI.create_declaration_with_termination_logic(@create_attrs)

      %{id: ^id} = DeclarationAPI.get_declaration!(id)

      %{status: status, is_active: is_active} = DeclarationAPI.get_declaration!(id1)
      assert "terminated" == status
      refute is_active

      %{status: status, is_active: is_active} = DeclarationAPI.get_declaration!(id2)
      assert "active" == status
      assert is_active
    end

    test "with invalid data doesn't terminate other declarations and returns error changeset" do
      %{id: id} = fixture(:declaration)
      invalid_attrs = Map.put(@invalid_attrs, "person_id", "person_id")
      assert {:error, _transaction_step, %Ecto.Changeset{}, _}
        = DeclarationAPI.create_declaration_with_termination_logic(invalid_attrs)

      %{status: status, is_active: is_active} = DeclarationAPI.get_declaration!(id)
      assert "active" == status
      assert is_active
    end
  end

  test "update_declaration/2 with valid data updates the declaration" do
    declaration = fixture(:declaration)
    assert {:ok, declaration} = DeclarationAPI.update_declaration(declaration, @update_attrs)
    assert %Declaration{} = declaration

    assert declaration.person_id == "updated_person_id"
    assert declaration.start_date
    assert declaration.end_date
    assert declaration.status == "closed"
    assert declaration.scope == "family_doctor"
    assert declaration.signed_at
    assert declaration.created_by == @update_attrs["created_by"]
    assert declaration.updated_by == @update_attrs["updated_by"]
    refute declaration.is_active
    assert declaration.employee_id == "updated_employee_id"
    assert declaration.legal_entity_id == @update_attrs["legal_entity_id"]
  end

  test "update_declaration/2 with invalid data returns error changeset" do
    declaration = fixture(:declaration)
    assert {:error, %Ecto.Changeset{}} = DeclarationAPI.update_declaration(declaration, @invalid_attrs)
    assert declaration == DeclarationAPI.get_declaration!(declaration.id)
  end

  test "delete_declaration/1 deletes the declaration" do
    declaration = fixture(:declaration)
    assert {:ok, %Declaration{}} = DeclarationAPI.delete_declaration(declaration)
    assert_raise Ecto.NoResultsError, fn -> DeclarationAPI.get_declaration!(declaration.id) end
  end

  test "change_declaration/1 returns a declaration changeset" do
    declaration = fixture(:declaration)
    assert %Ecto.Changeset{} = DeclarationAPI.change_declaration(declaration)
  end
end
