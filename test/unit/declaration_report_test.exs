defmodule OPS.Declaration.ReportTest do
  use OPS.DataCase

  alias OPS.DeclarationAPI

  @create_attrs %{
    employee_id: Ecto.UUID.generate(),
    person_id: Ecto.UUID.generate(),
    start_date: "2016-10-10 00:00:00.000000",
    end_date: "2016-12-07 00:00:00.000000",
    status: "active",
    signed_at: "2016-10-09 23:50:07.000000",
    created_by: Ecto.UUID.generate(),
    updated_by: Ecto.UUID.generate(),
    is_active: true,
    scope: "family_doctor",
    division_id: Ecto.UUID.generate(),
    legal_entity_id: Ecto.UUID.generate(),
  }

  def fixture(:declaration, attrs \\ @create_attrs) do
    create_attrs =
      attrs
      |> Map.put(:employee_id, Ecto.UUID.generate())
      |> Map.put(:legal_entity_id, Ecto.UUID.generate())

    {:ok, declaration} = DeclarationAPI.create_declaration(create_attrs)
    declaration
  end

  test "report" do
    declaration = fixture(:declaration)
    params = %{
      "start_date" => "2016-12-09 00:00:00.000000",
      "end_date" => "2017-12-09 00:00:00.000000",
      "employee_id" => declaration.employee_id,
      "legal_entity_id" => declaration.legal_entity_id
    }
    assert {:ok, list} = OPS.Declaration.Report.report(params)
    assert is_list(list)
  end
end
