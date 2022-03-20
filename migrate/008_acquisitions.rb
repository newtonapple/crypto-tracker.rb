# frozen_string_literal: true

Sequel.migration do
  up do
    create_enum(
      :acquisition_type,
      %w[
        buy
        exchange
        refund
        income
        interest
        reward
        airdrop
        staking
        mining
        fork
        gift_received
      ]
    )
    create_table(:acquisitions) do
      primary_key :id
      Integer :transaction_id, unique: true
      foreign_key :account_id, :accounts, null: false
      foreign_key :currency_id, :currencies, null: false
      BigDecimal :amount, null: false
      foreign_key :cost_currency_id, :currencies
      BigDecimal :cost_amount
      BigDecimal :average_cost_amount
      Boolean :has_cost, default: false, null: false
      acquisition_type :type, null: false
      DateTime :acquired_at, null: false
      DateTime :created_at, null: false

      index %i[account_id acquired_at]

      index %i[account_id has_cost acquired_at]
      index %i[account_id has_cost currency_id acquired_at]
      index %i[account_id has_cost currency_id type acquired_at]

      index %i[account_id type acquired_at]
      index %i[account_id currency_id acquired_at]
      index %i[account_id currency_id type acquired_at]

      index %i[created_at account_id]
    end
  end

  down do
    drop_table(:acquisitions)
    drop_enum(:acquisition_type)
  end
end
