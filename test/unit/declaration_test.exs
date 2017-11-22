defmodule OPS.DeclarationTest do
  use OPS.DataCase

  alias Scrivener.Page
  alias EctoTrail.Changelog
  alias OPS.Declarations
  alias OPS.Declarations.Declaration

  @create_attrs %{
    "id" => Ecto.UUID.generate(),
    "employee_id" => Ecto.UUID.generate(),
    "start_date" => "2016-10-10",
    "end_date" => "2016-12-07",
    "status" => "active",
    "signed_at" => "2016-10-09T23:50:07.000000Z",
    "created_by" => Ecto.UUID.generate(),
    "updated_by" => Ecto.UUID.generate(),
    "is_active" => true,
    "scope" => "family_doctor",
    "division_id" => Ecto.UUID.generate(),
    "legal_entity_id" => Ecto.UUID.generate(),
    "declaration_request_id" => Ecto.UUID.generate(),
  }

  @update_attrs %{
    "employee_id" => Ecto.UUID.generate(),
    "person_id" => Ecto.UUID.generate(),
    "start_date" => "2016-10-11",
    "end_date" => "2016-12-08",
    "status" => "closed",
    "signed_at" => "2016-10-10T23:50:07.000000Z",
    "created_by" => Ecto.UUID.generate(),
    "updated_by" => Ecto.UUID.generate(),
    "is_active" => false,
    "scope" => "family_doctor",
    "division_id" => Ecto.UUID.generate(),
    "legal_entity_id" => Ecto.UUID.generate(),
  }

   @invalid_attrs %{
     "division_id" => "invalid"
   }

  setup do
    {:ok, initial_block} = insert_initial_block()

    {:ok, %{hash: initial_block.hash}}
  end

  def fixture(:declaration, attrs \\ @create_attrs) do
    person_id = if Map.has_key?(attrs, "person_id"), do: attrs, else: Ecto.UUID.generate()
    create_attrs =
      attrs
      |> Map.put("person_id", person_id)
      |> Map.put("id", Ecto.UUID.generate())
      |> Map.put("employee_id", Ecto.UUID.generate())
      |> Map.put("legal_entity_id", Ecto.UUID.generate())
      |> Map.put("declaration_request_id", Ecto.UUID.generate())

    {:ok, declaration} = Declarations.create_declaration(create_attrs)
    declaration
  end

  test "declaration is assigned a seed", %{hash: hash} do
    declaration = fixture(:declaration)
    assert declaration.seed == hash
  end

  test "list_declarations/1 returns all declarations" do
    declaration = fixture(:declaration)
    assert %Page{entries: [^declaration]} = Declarations.list_declarations(%{})
  end

  test "get_declaration! returns the declaration with given id" do
    declaration = fixture(:declaration)
    assert Declarations.get_declaration!(declaration.id) == declaration
  end

  test "create_declaration/1 with valid data creates a declaration" do
    create_attrs =
      @create_attrs
      |> Map.put("id", Ecto.UUID.generate())
      |> Map.put("employee_id", Ecto.UUID.generate())
      |> Map.put("legal_entity_id", Ecto.UUID.generate())
      |> Map.put("person_id", Ecto.UUID.generate())

    assert {:ok, %Declaration{} = declaration} = Declarations.create_declaration(create_attrs)
    assert declaration.id == create_attrs["id"]
    assert declaration.person_id == create_attrs["person_id"]
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
    assert {:error, %Ecto.Changeset{}} = Declarations.create_declaration(@invalid_attrs)
  end

  describe "create_declaration_with_termination_logic/1" do
    test "with valid data creates declaration and terminates other person declarations" do
      %{id: id1, person_id: person_id} = fixture(:declaration)
      params = Map.put(@create_attrs, "person_id", person_id)
      {:ok, %{new_declaration: %{id: id}}} = Declarations.create_declaration_with_termination_logic(params)

      %{id: ^id, status: status} = Declarations.get_declaration!(id)
      assert "active" == status

      %{status: status} = Declarations.get_declaration!(id1)
      assert "terminated" == status
    end

    test "with invalid data doesn't terminate other declarations and returns error changeset" do
      %{id: id} = fixture(:declaration)
      invalid_attrs = Map.put(@invalid_attrs, "person_id", "person_id")
      assert {:error, _transaction_step, %Ecto.Changeset{}, _}
        = Declarations.create_declaration_with_termination_logic(invalid_attrs)

      %{status: status} = Declarations.get_declaration!(id)
      assert "active" == status
    end
  end

  describe "update_declaration/2" do
    test "updates the declaration when data is valid" do
      declaration = fixture(:declaration)
      assert {:ok, declaration} = Declarations.update_declaration(declaration, @update_attrs)
      assert %Declaration{} = declaration

      assert declaration.person_id == @update_attrs["person_id"]
      assert declaration.start_date
      assert declaration.end_date
      assert declaration.status == "closed"
      assert declaration.scope == "family_doctor"
      assert declaration.signed_at
      assert declaration.created_by == @update_attrs["created_by"]
      assert declaration.updated_by == @update_attrs["updated_by"]
      refute declaration.is_active
      assert declaration.employee_id == @update_attrs["employee_id"]
      assert declaration.legal_entity_id == @update_attrs["legal_entity_id"]
    end

    test "returns error when data is not valid" do
      declaration = fixture(:declaration, Map.put(@create_attrs, "status", "pending_verification"))
      assert {:error, %Ecto.Changeset{}} = Declarations.update_declaration(declaration, @invalid_attrs)
      assert declaration == Declarations.get_declaration!(declaration.id)
    end

    test "successfully transitions declaration to a new status" do
      declaration = fixture(:declaration, Map.put(@create_attrs, "status", "pending_verification"))
      updates = %{"status" => "active", "updated_by" => Ecto.UUID.generate()}
      {:ok, _update_result} = Declarations.update_declaration(declaration, updates)
    end

    test "returns error when status transition is not correct" do
      declaration = fixture(:declaration, Map.put(@create_attrs, "status", "active"))
      updates = %{"status" => "pending_verification", "updated_by" => Ecto.UUID.generate()}
      {:error, changeset} = Declarations.update_declaration(declaration, updates)

      assert "Incorrect status transition." = elem(changeset.errors[:status], 0)
    end
  end

  test "delete_declaration/1 deletes the declaration" do
    declaration = fixture(:declaration)
    assert {:ok, %Declaration{}} = Declarations.delete_declaration(declaration)
    assert_raise Ecto.NoResultsError, fn -> Declarations.get_declaration!(declaration.id) end
  end

  test "change_declaration/1 returns a declaration changeset" do
    declaration = fixture(:declaration)
    assert %Ecto.Changeset{} = Declarations.change_declaration(declaration)
  end

  describe "terminate_declarations/1" do
    test "declaration termination is audited" do
      user_id = "ab4b2245-55c9-46eb-9ac6-c751020a46e3"
      employee_id = "84e30a11-94bd-49fe-8b1f-f5511c5916d6"

      dec1 = fixture(:declaration)
      dec2 = fixture(:declaration, Map.merge(@create_attrs, %{"status" => "pending_verification"}))
      dec3 = fixture(:declaration, Map.merge(@create_attrs, %{"status" => "pending_verification"}))

      Repo.update_all(Declaration, set: [employee_id: employee_id])

      OPS.Declarations.terminate_declarations(user_id, employee_id)

      Enum.each [dec1, dec2, dec3], fn declaration ->
        declaration = Repo.get(Declaration, declaration.id)

        assert "terminated" == declaration.status
        assert user_id == declaration.updated_by

        audit_log = Repo.one!(
          from cl in Changelog,
          where: cl.resource == "declarations"
                 and cl.resource_id == ^declaration.id
                 and fragment("?->>?", cl.changeset, "status") == "terminated")

        assert user_id == audit_log.changeset["updated_by"]
      end
    end
  end

  describe "terminate_person_declarations/1" do
    test "terminates person declarations" do
      user_id = Confex.fetch_env!(:ops, :system_user)
      person_id = "84e30a11-94bd-49fe-8b1f-f5511c5916d6"

      # TODO: make statuses different. termination should pick up an terminate declarations
      # in all statuses
      dec1 = fixture(:declaration)
      dec2 = fixture(:declaration, Map.merge(@create_attrs, %{"status" => "closed"}))
      dec3 = fixture(:declaration, Map.merge(@create_attrs, %{"status" => "rejected"}))

      Repo.update_all(Declaration, set: [person_id: person_id])

      OPS.Declarations.terminate_person_declarations(user_id, person_id)

      Enum.each [dec1, dec2, dec3], fn declaration ->
        declaration = Repo.get(Declaration, declaration.id)

        assert "terminated" == declaration.status
        assert user_id == declaration.updated_by

        audit_log = Repo.one!(
          from cl in Changelog,
          where: cl.resource == "declarations"
                 and cl.resource_id == ^declaration.id
                 and fragment("?->>?", cl.changeset, "status") == "terminated")

        assert user_id == audit_log.changeset["updated_by"]
      end
    end
  end
end
