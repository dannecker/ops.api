defmodule OPS.MedicationRequests do
  @moduledoc false

  alias OPS.MedicationRequest.Schema, as: MedicationRequest
  alias OPS.MedicationDispense.Schema, as: MedicationDispense
  alias OPS.Repo
  alias OPS.MedicationRequest.Search
  alias OPS.Declarations.Declaration
  alias OPS.MedicationRequest.DoctorSearch
  alias OPS.MedicationRequest.QualifySearch
  import Ecto.Changeset
  alias Ecto.Multi
  use OPS.Search

  def list(params) do
    %Search{}
    |> changeset(params)
    |> search(params, MedicationRequest)
  end

  def doctor_list(params) do
    %DoctorSearch{}
    |> changeset(params)
    |> doctor_search()
    |> Repo.paginate(params)
  end

  def qualify_list(params) do
    %QualifySearch{}
    |> changeset(params)
    |> qualify_search()
  end

  def prequalify_list(params) do
    %QualifySearch{}
    |> changeset(params)
    |> prequalify_search()
  end

  def update(medication_request, attrs) do
    medication_request
    |> changeset(attrs)
    |> Repo.update_and_log(Map.get(attrs, "updated_by"))
  end

  def create(%{"medication_request" => mr}) do
    %MedicationRequest{}
    |> create_changeset(mr)
    |> Repo.insert()
  end

  defp doctor_search(%Ecto.Changeset{valid?: true, changes: changes} = changeset) do
    employee_ids =
      changeset
      |> get_change(:employee_id, "")
      |> String.split(",")
      |> Enum.filter(&(&1 != ""))
    filters = changes
      |> Map.delete(:employee_id)
      |> Map.to_list()

    MedicationRequest
    |> join(:left, [mr], d in Declaration,
      d.employee_id == mr.employee_id and
      d.person_id == mr.person_id and
      d.status == ^Declaration.status(:active)
    )
    |> where([mr], ^filters)
    |> filter_by_employees(employee_ids)
  end
  defp doctor_search(changeset), do: {:error, changeset}

  defp qualify_search(%Ecto.Changeset{valid?: true} = changeset) do
     qualify_query(changeset, :qualify)
  end
  defp qualify_search(changeset), do: {:error, changeset}

  defp prequalify_search(%Ecto.Changeset{valid?: true} = changeset) do
    qualify_query(changeset, :prequalify)
  end
  defp prequalify_search(changeset), do: {:error, changeset}

  def qualify_query(%Ecto.Changeset{valid?: true, changes: changes} = changeset, pre_or_qualify) do
    filters =
      changes
      |> Map.take(~w(person_id)a)
      |> Map.to_list()
    started_at = get_change(changeset, :started_at)
    ended_at = get_change(changeset, :ended_at)
    medication_request_statuses = [
      MedicationRequest.status(:active),
      MedicationRequest.status(:completed)
    ]
    query =
      MedicationRequest
      |> where([mr], ^filters)
      |> where([mr], mr.status in ^medication_request_statuses)
      |> where([mr], fragment("not (? > ? or ? < ?)",
        ^started_at,
        mr.ended_at,
        ^ended_at,
        mr.started_at
      ))
      |> select([mr], mr.medication_id)
    case pre_or_qualify do
      :qualify ->
        query
        |> join(:left, [mr], md in MedicationDispense, md.medication_request_id == mr.id)
        |> where([mr, md], md.status == ^MedicationDispense.status(:processed))
      :prequalify -> query
    end

    {:ok, Repo.all(query)}
  end

  defp filter_by_employees(query, []), do: query
  defp filter_by_employees(query, employee_ids) do
    where(query, [mr], mr.employee_id in ^employee_ids)
  end

  defp changeset(%Search{} = search, attrs) do
    # allow to search by all available fields
    cast(search, attrs, Search.__schema__(:fields))
  end
  defp changeset(%DoctorSearch{} = search, attrs) do
    cast(search, attrs, DoctorSearch.__schema__(:fields))
  end
  defp changeset(%MedicationRequest{} = medication_request, attrs) do
    cast(medication_request, attrs, MedicationRequest.__schema__(:fields))
  end
  defp changeset(%QualifySearch{} = search, attrs) do
    search
    |> cast(attrs, QualifySearch.__schema__(:fields))
    |> validate_required(QualifySearch.__schema__(:fields))
  end

  defp create_changeset(%MedicationRequest{} = medication_request, attrs) do
    medication_request
    |> cast(attrs, MedicationRequest.__schema__(:fields))
    |> put_change(:status, MedicationRequest.status(:active))
    |> put_change(:is_active, true)
  end

  def terminate do
    query =
      MedicationRequest
      |> where([mr], mr.status == ^MedicationRequest.status(:active))
      |> where([mr], mr.ended_at <= ^Date.utc_today())

    Multi.new()
    |> Multi.update_all(:medication_requests, query, set: [
      status: MedicationRequest.status(:expired),
      updated_by: Confex.fetch_env!(:ops, :system_user),
      updated_at: NaiveDateTime.utc_now()
    ])
    |> Repo.transaction()
  end
end
