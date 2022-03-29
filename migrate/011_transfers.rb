# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:transfers) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false
      foreign_key :from_account_id, :accounts, null: false
      foreign_key :to_account_id, :accounts, null: false
      foreign_key :from_transaction_id, :transactions, index: true
      foreign_key :to_transaction_id, :transactions, index: true
      foreign_key :currency_id, :currencies, null: false
      foreign_key :fiat_currency_id, :currencies

      # crypto
      BigDecimal :amount, null: false

      # fiat
      BigDecimal :cost_amount
      BigDecimal :average_cost_amount
      BigDecimal :account_cost_amount, default: 0
      BigDecimal :account_average_cost_amount, default: 0

      DateTime :from_completed_at, null: false
      DateTime :to_completed_at, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index %i[portfolio_id from_completed_at]
      index %i[portfolio_id to_completed_at]
      index %i[portfolio_id currency_id from_completed_at]
      index %i[portfolio_id currency_id to_completed_at]

      index %i[from_account_id from_completed_at]
      index %i[to_account_id to_completed_at]
      index %i[from_account_id currency_id from_completed_at]
      index %i[to_account_id currency_id to_completed_at]
    end
  end
end
