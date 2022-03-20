# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:portfolios) do
      primary_key :id
      String :name, null: false, index: true, size: 255
      DateTime :created_at, null: false, index: true
      DateTime :updated_at, null: false
    end
  end
end
