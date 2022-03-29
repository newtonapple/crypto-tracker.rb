# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:assets) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false
      foreign_key :account_id, :accounts, null: false
      foreign_key :currency_id, :currencies, null: false
      foreign_key :cost_currency_id, :currencies, null: false
      foreign_key :acquisition_id, :acquisitions, null: false, index: true
      acquisition_type :type, null: false
      BigDecimal :amount, null: false
      BigDecimal :cost_amount, null: false                # fiat
      BigDecimal :average_cost_amount, null: false        # fiat
      BigDecimal :account_cost_amount, default: 0         # fiat
      BigDecimal :account_average_cost_amount, default: 0 # fiat
      DateTime :acquired_at, null: false
      DateTime :account_acquired_at, null: false
      DateTime :transferred_in_at
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index %i[portfolio_id currency_id acquired_at]
      index %i[portfolio_id currency_id transferred_in_at]
      index %i[portfolio_id account_id currency_id acquired_at amount]
      index %i[portfolio_id account_id currency_id average_cost_amount acquired_at amount]
      index %i[portfolio_id account_id currency_id account_acquired_at amount]
      index %i[portfolio_id account_id currency_id account_average_cost_amount account_acquired_at amount]
      index %i[created_at account_id]
      index %i[updated_at account_id]
    end
  end
end
