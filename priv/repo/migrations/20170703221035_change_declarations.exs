defmodule OPS.Repo.Migrations.ChangeDeclarations do
  use Ecto.Migration

  def change do
    alter table(:declarations) do
      remove :declaration_signed_id
      remove :employee_id
      add :employee_id, :uuid, null: false
      remove :person_id
      add :person_id, :uuid, null: false
      remove :legal_entity_id
      add :legal_entity_id, :uuid, null: false
    end
  end
end
