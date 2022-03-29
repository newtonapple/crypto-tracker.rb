# frozen_string_literal: true

Sequel.migration do
  up do
    create_enum(
      :disposal_type,
      %w[
        sell
        exchange
        gift_sent
        payment
        fee
        loss_investment
        loss_theft
        loss_casualty
      ]
    )

    create_enum(:capital_gains_treatment, %w[short_term long_term])

    create_table(:disposals) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false
      foreign_key :account_id, :accounts, null: false
      foreign_key :currency_id, :currencies, null: false
      foreign_key :fiat_currency_id, :currencies, null: false
      Integer :transaction_id, index: true
      foreign_key :acquisition_id, :acquisitions, null: false, index: true
      acquisition_type :acquisition_type, null: false
      disposal_type :type, null: false
      capital_gains_treatment :capital_gains_treatment, null: false
      capital_gains_treatment :account_capital_gains_treatment, null: false

      BigDecimal :amount, null: false
      BigDecimal :cost_amount, null: false                     # fiat
      BigDecimal :sold_amount, null: false                     # fiat
      BigDecimal :net_amount, null: false                      # fiat
      BigDecimal :account_cost_amount, null: false, default: 0 # fiat
      BigDecimal :account_net_amount, null: false, default: 0  # fiat

      DateTime :acquired_at, null: false
      DateTime :account_acquired_at, null: false
      DateTime :disposed_at, null: false
      DateTime :created_at, null: false, index: true

      index %i[portfolio_id account_id disposed_at acquired_at]
      index %i[portfolio_id account_id capital_gains_treatment disposed_at acquired_at]
      index %i[portfolio_id account_id type disposed_at acquired_at]
      index %i[portfolio_id account_id currency_id disposed_at acquired_at]
      index %i[portfolio_id account_id currency_id type disposed_at acquired_at]

      index %i[portfolio_id disposed_at acquired_at]
      index %i[portfolio_id capital_gains_treatment disposed_at acquired_at]
      index %i[portfolio_id type disposed_at acquired_at]
      index %i[portfolio_id currency_id disposed_at acquired_at]
      index %i[portfolio_id currency_id type disposed_at acquired_at]
    end
  end

  down do
    drop_table(:disposals)
    drop_enum(:disposal_type)
    drop_enum(:capital_gains_treatment)
  end
end
