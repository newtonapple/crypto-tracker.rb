# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:platforms) do
      primary_key :id
      String :name, null: false, index: { unique: true }, size: 255
      String :url
      DateTime :created_at, null: false, index: true
      DateTime :updated_at, null: false, index: true
    end
  end
end
