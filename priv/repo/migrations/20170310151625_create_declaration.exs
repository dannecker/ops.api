defmodule PRM.Repo.Migrations.CreatePrm.Declaration do
  use Ecto.Migration

  def change do
    create table(:declarations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :declaration_signed_id, :uuid, null: false
      add :employee_id, :string, null: false
      add :person_id, :string, null: false
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :status, :string, null: false
      add :signed_at, :utc_datetime, null: false
      add :created_by, :uuid, null: false
      add :updated_by, :uuid, null: false
      add :is_active, :boolean, default: false
      add :scope, :string, null: false
      add :division_id, :uuid, null: false
      add :legal_entity_id, :string, null: false

      timestamps([type: :utc_datetime])
    end

    create table(:declaration_signed, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :document_type, :string, null: false
      add :document, :map, null: false

      timestamps([type: :utc_datetime])
    end

    create table(:declaration_log_changes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :string, null: false
      add :resource, :string, null: false
      add :what_changed, :map, null: false

      timestamps([type: :utc_datetime, updated_at: false])
    end
  end
end
