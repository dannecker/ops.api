defmodule OPS.Web.MedicationRequestControllerTest do
  use OPS.Web.ConnCase

  alias OPS.MedicationRequest.Schema, as: MedicationRequest
  alias OPS.MedicationDispense.Schema, as: MedicationDispense

  setup %{conn: conn} do
    medication_request1 = insert(:medication_request)
    medication_request2 = insert(:medication_request, status: MedicationRequest.status(:completed))
    {:ok,
     conn: put_req_header(conn, "accept", "application/json"),
     data: [medication_request1, medication_request2]
    }
  end

  describe "search medication requests" do
    test "success default search", %{conn: conn} do
      conn = get conn, medication_request_path(conn, :index)
      resp = json_response(conn, 200)["data"]
      assert 2 == length(resp)
    end

    test "success search by id", %{conn: conn, data: [medication_request1, _]} do
      conn = get conn, medication_request_path(conn, :index, id: medication_request1.id)
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert medication_request1.id == hd(resp)["id"]
    end

    test "success search by person_id", %{conn: conn, data: [medication_request1, _]} do
      conn = get conn, medication_request_path(conn, :index,
        person_id: medication_request1.person_id
      )
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert medication_request1.person_id == hd(resp)["person_id"]
    end

    test "success search by employee_id", %{conn: conn, data: [medication_request1, _]} do
      conn = get conn, medication_request_path(conn, :index,
        employee_id: medication_request1.employee_id
      )
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert medication_request1.employee_id == hd(resp)["employee_id"]
    end

    test "success search by status", %{conn: conn, data: [_, medication_request2]} do
      conn = get conn, medication_request_path(conn, :index,
        status: medication_request2.status
      )
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert medication_request2.status == hd(resp)["status"]
    end

    test "success search by list of statuses", %{conn: conn} do
      conn = get conn, medication_request_path(conn, :index, status: "ACTIVE,COMPLETED")
      resp = json_response(conn, 200)["data"]
      assert 2 == length(resp)
    end

    test "success search by all possible params", %{conn: conn, data: [_, medication_request2]} do
      conn = get conn, medication_request_path(conn, :index,
        status: medication_request2.status,
        person_id: medication_request2.person_id,
        employee_id: medication_request2.employee_id,
      )
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert medication_request2.status == hd(resp)["status"]
      assert medication_request2.person_id == hd(resp)["person_id"]
      assert medication_request2.employee_id == hd(resp)["employee_id"]
    end
  end

  describe "search medication requests for doctors" do
    test "success search", %{conn: conn, data: [medication_request, _]} do
      insert(:declaration,
        employee_id: medication_request.employee_id,
        person_id: medication_request.person_id
      )
      conn = get conn, medication_request_path(conn, :doctor_list, %{
        "employee_id" => "#{medication_request.employee_id},#{Ecto.UUID.generate()}",
        "person_id" => medication_request.person_id,
        "id" => medication_request.id,
      })
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
    end

    test "empty search", %{conn: conn, data: [medication_request, _]} do
      insert(:declaration,
        employee_id: medication_request.employee_id,
        person_id: medication_request.person_id
      )
      conn = get conn, medication_request_path(conn, :doctor_list, %{"status" => "invalid"})
      resp = json_response(conn, 200)["data"]
      assert 0 == length(resp)
    end
  end

  describe "qualify search medication requests" do
    test "success search", %{conn: conn, data: [medication_request, _]} do
      %{person_id: person_id, medication_id: medication_id} = medication_request
      insert(:medication_dispense,
        medication_request: medication_request,
        status: MedicationDispense.status(:processed)
      )
      today = Date.utc_today()
      conn = get conn, medication_request_path(conn, :qualify_list, %{
        "person_id" => person_id,
        "started_at" => to_string(Date.add(today, -1)),
        "ended_at" => to_string(Date.add(today, 1)),
      })
      resp = json_response(conn, 200)["data"]
      assert [medication_id] == resp
    end

    test "empty search", %{conn: conn} do
      today = to_string(Date.utc_today())
      conn = get conn, medication_request_path(conn, :qualify_list, %{
        "person_id" => Ecto.UUID.generate(),
        "started_at" => today,
        "ended_at" => today,
      })
      resp = json_response(conn, 200)["data"]
      assert [] == resp
    end

    test "empty request", %{conn: conn} do
      conn = get conn, medication_request_path(conn, :qualify_list)
      assert json_response(conn, 422)
    end

    test "invalid dates request", %{conn: conn} do
      conn = get conn, medication_request_path(conn, :qualify_list, %{
        "person_id" => Ecto.UUID.generate(),
        "started_at" => "invalid",
        "endded_at" => "invalid"
      })
      assert json_response(conn, 422)
    end
  end

  describe "update medication request" do
    test "success update", %{conn: conn, data: [medication_request, _]} do
      conn = patch conn, medication_request_path(conn, :update, medication_request.id), %{
        "medication_request" => %{
          "status" => MedicationRequest.status(:completed),
          "updated_by" => Ecto.UUID.generate(),
        },
      }
      resp = json_response(conn, 200)
      assert MedicationRequest.status(:completed) == resp["data"]["status"]
    end
  end

  describe "create medication request" do
    test "creates with valid data", %{conn: conn, data: [medication_request, _]} do
      id = Ecto.UUID.generate()
      mr =
        medication_request
        |> Map.put(:id, id)
        |> Map.put(:request_number, id)
      conn = post conn, medication_request_path(conn, :create), %{
        "medication_request" => Map.from_struct(mr)
      }
      assert json_response(conn, 201)
      assert json_response(conn, 201)["data"]["id"] == id
    end
  end
end
