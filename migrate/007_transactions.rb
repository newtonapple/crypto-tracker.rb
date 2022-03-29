# frozen_string_literal: true

Sequel.migration do
  up do
    create_enum(
      :transaction_type,
      %w[
        transfer_out
        transfer_in
        buy
        sell
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
      String :platform_transaction_id, null: false

      foreign_key :from_wallet_id, :account_wallets
      foreign_key :to_wallet_id, :account_wallets

      foreign_key :from_currency_id, :currencies, null: false
      foreign_key :to_currency_id, :currencies, null: false
      foreign_key :fee_currency_id, :currencies
      foreign_key :market_value_currency_id, :currencies
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

      unique %i[account_id type platform_transaction_id]
      index %i[portfolio_id completed_at type]

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
