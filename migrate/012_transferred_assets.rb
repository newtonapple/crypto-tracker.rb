# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:transferred_assets) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false
      foreign_key :from_account_id, :accounts, null: false
      foreign_key :to_account_id, :accounts, null: false
      foreign_key :transfer_id, :transfers, null: false, index: true
      foreign_key :currency_id, :currencies, null: false
      foreign_key :cost_currency_id, :currencies, null: false
      foreign_key :acquisition_id, :acquisitions, null: false, index: true
      acquisition_type :acquisition_type, null: false

      # crypto
      BigDecimal :amount, null: false

      # fiat
      BigDecimal :cost_amount
      BigDecimal :average_cost_amount
      BigDecimal :account_cost_amount, default: 0
      BigDecimal :account_average_cost_amount, default: 0

      DateTime :acquired_at, null: false
      DateTime :account_acquired_at, null: false
      DateTime :created_at, null: false

      index %i[created_at portfolio_id]
      index %i[portfolio_id created_at]
      index %i[portfolio_id currency_id created_at]

      index %i[from_account_id created_at]
      index %i[to_account_id created_at]
      index %i[from_account_id currency_id created_at]
      index %i[to_account_id currency_id created_at]
    end
  end
end
