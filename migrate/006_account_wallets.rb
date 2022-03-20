# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:account_wallets) do
      primary_key :id
      foreign_key :account_id, :accounts, null: false
      foreign_key :wallet_id, :wallets, null: false
      DateTime :created_at, null: false, index: true
      unique %i[account_id wallet_id]
    end
  end
end
