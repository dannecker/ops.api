defmodule OPS.Web.MedicationRequestController do
  @moduledoc false

  use OPS.Web, :controller

  alias Scrivener.Page
  alias OPS.MedicationRequests

  action_fallback OPS.Web.FallbackController

  def index(conn, params) do
    with %Page{} = paging <- MedicationRequests.list(params) do
      render(conn, "index.json", medication_requests: paging.entries, paging: paging)
    end
  end

  def doctor_list(conn, params) do
    with %Page{} = paging <- MedicationRequests.doctor_list(params) do
      render(conn, "index.json", medication_requests: paging.entries, paging: paging)
    end
  end

  def qualify_list(conn, params) do
    with {:ok, ids} <- MedicationRequests.qualify_list(params) do
      render(conn, "qualify_list.json", ids: ids)
    end
  end

  def create(conn, params) do
    with {:ok, medication_request} <- MedicationRequests.create(params)
    do
      conn
      |> put_status(:created)
      |> render("show.json", medication_request: medication_request)
    end
  end

  def update(conn, %{"id" => id, "medication_request" => params}) do
    with %Page{entries: [medication_request]} <- MedicationRequests.list(%{"id" => id}),
      {:ok, medication_request} <- MedicationRequests.update(medication_request, params)
    do
      render(conn, "show.json", medication_request: medication_request)
    end
  end
end
