# frozen_string_literal: true

Sequel.migration do
  up do
    create_enum(
      :accounting_method,
      %w[
        fifo
        lifo
        hifo
        spec
      ]
    )
    create_table(:accounts) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false
      foreign_key :platform_id, :platforms, null: false
      String :platform_account_id
      String :name, null: false, size: 255
      accounting_method :accounting_method, null: false, default: 'fifo'

      Date :started_on, null: false
      DateTime :created_at, null: false, index: true
      DateTime :updated_at, null: false

      index %i[portfolio_id platform_id]
      index %i[portfolio_id platform_id name]
      index %i[portfolio_id platform_id platform_account_id]
    end
  end

  down do
    drop_table(:accounts)
    drop_enum(:accounting_method)
  end
end
