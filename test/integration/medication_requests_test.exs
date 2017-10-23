defmodule OPS.MedicationRequestsTest do
  @moduledoc false

  use OPS.Web.ConnCase

  alias OPS.MedicationRequest.Schema, as: MedicationRequest
  alias OPS.MedicationRequests
  alias OPS.Repo

  test "terminate/1" do
    insert(:medication_request, ended_at: "2017-01-01")

    assert 1 == count_by_status(MedicationRequest.status(:active))

    MedicationRequests.terminate()

    assert 0 == count_by_status(MedicationRequest.status(:active))
    assert 1 == count_by_status(MedicationRequest.status(:expired))
  end

  defp count_by_status(status) do
    MedicationRequest
    |> where([mr], mr.status == ^status)
    |> select([mr], count(mr.id))
    |> Repo.one
  end
end
