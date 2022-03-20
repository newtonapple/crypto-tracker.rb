# frozen_string_literal: true

Sequel.migration do
  up do
    create_enum(
      :transaction_type,
      %w[
        buy
        sell
        exchange
        transfer_in
        transfer_out
        refund
        income
        interest
        reward
        airdrop
        staking
        mining
        fork
        gift_received
        gift_sent
        payment
        fee
        loss_investment
        loss_theft
        loss_casualty
      ]
    )

    create_table(:transactions) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false
      foreign_key :account_id, :accounts, null: false
      String  :platform_transaction_id, null: false

      Integer :from_wallet_id, index: true
      Integer :to_wallet_id, index: true

      Integer :from_currency_id, null: false
      Integer :to_currency_id, null: false
      Integer :fee_currency_id
      Integer :market_value_currency_id
      # BigDecimal :from_amount, size: [27, 18]
      # BigDecimal :to_amount, size: [27, 18]
      # BigDecimal :fee, size: [27, 18]

      BigDecimal :from_amount
      BigDecimal :to_amount
      BigDecimal :market_value
      BigDecimal :fee

      transaction_type :type, null: false
      Boolean :processed, default: false, null: false

      DateTime :completed_at, null: false
      DateTime :created_at, null: false, index: true
      DateTime :updated_at, null: false

      index %i[portfolio_id completed_at type]

      unique %i[account_id type platform_transaction_id]
      index %i[account_id platform_transaction_id]
      index %i[account_id completed_at type]
      index %i[account_id processed completed_at type]
      index %i[account_id processed type completed_at]

      index %i[account_id from_currency_id]
      index %i[account_id to_currency_id]
      index %i[account_id type from_currency_id]
      index %i[account_id type to_currency_id]
      index %i[account_id type completed_at]
    end
  end

  down do
    drop_table(:transactions)
    drop_enum(:transaction_type)
  end
end
