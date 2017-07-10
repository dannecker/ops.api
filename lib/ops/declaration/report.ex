defmodule OPS.Declarations.Report do
  @moduledoc false

  import Ecto.Changeset, warn: false

  alias Ecto.Adapters.SQL

  def report(%Ecto.Changeset{valid?: false} = changeset), do: changeset
  def report(%Ecto.Changeset{valid?: true} = changeset) do
    start_date = get_change(changeset, :start_date)
    end_date = get_change(changeset, :end_date)
    query = "
          SELECT days.day,
                 count(case when DATE(inserted_at) = day then 1 end) as created,
                 count(case when status = 'closed' and DATE(updated_at) = day then 1 end) as closed,
                 count(case when status != 'closed' and DATE(inserted_at) <= day then 1 end) as total
            FROM declarations
      RIGHT JOIN (
                   SELECT date_trunc('day', series)::date AS day
                   FROM generate_series('#{start_date}'::timestamp, '#{end_date}'::timestamp, '1 day'::interval) series
                 ) days ON
                           employee_id = '#{get_change(changeset, :employee_id)}' AND
                           legal_entity_id = '#{get_change(changeset, :legal_entity_id)}' AND
                           inserted_at::date BETWEEN DATE('#{start_date}') AND DATE('#{end_date}')
        GROUP BY days.day
        ORDER BY days.day;
    "

    {:ok, result} = SQL.query(OPS.Repo, query)

    list = Enum.map result.rows, fn item ->
      %{
        date: Date.from_erl!(Enum.at(item, 0)),
        created: Enum.at(item, 1),
        closed: Enum.at(item, 2),
        total: Enum.at(item, 3)
      }
    end
    {:ok, list}
  end

  def report(params) do
    params
    |> report_changeset()
    |> report()
  end

  def report_changeset(attrs) do
    data = %{}
    types = %{
      start_date: :date,
      end_date: :date,
      employee_id: Ecto.UUID,
      legal_entity_id: Ecto.UUID
    }
    required_fields = [
      :start_date,
      :end_date,
      :employee_id,
      :legal_entity_id
    ]

    {data, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(required_fields)
  end
end
