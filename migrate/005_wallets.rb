# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:wallets) do
      primary_key :id
      foreign_key :platform_id, :platforms, null: false
      foreign_key :currency_id, :currencies, null: false
      String :address, null: false, index: true
      DateTime :created_at, null: false, index: true
      DateTime :updated_at, null: false, index: true

      index %i[platform_id currency_id address], unique: true
      index %i[currency_id address]
    end
  end
end
