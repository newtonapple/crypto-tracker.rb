
# frozen_string_literal: true

require 'csv'

module Importers
  # Importer for Coinbase Raw Transactions CSV from https://accounts.coinbase.com/taxes/documents
  class Coinbase
    TIME            = 'Date & time'
    ACQUIRED_ASSET  = 'Asset Acquired'
    DISPOSED_ASSET  = 'Asset Disposed (Sold, Sent, etc)'
    ACQUIRED_AMOUNT = 'Quantity Acquired (Bought, Received, etc)'
    DISPOSED_AMOUNT = 'Quantity Disposed'
    COST            = 'Cost Basis (incl. fees paid) (USD)'
    PROCEEDS        = 'Proceeds (excl. fees paid) (USD)'
    TRADE_ID        = 'Transaction ID'
    TYPE            = 'Transaction Type'
    SOURCE          = 'Data Source'

    attr_reader :account, :fiat_currency, :transactions

    def initialize(account:, fiat_currency: Currency.by_symbol('USD'))
      @account = account
      @fiat_currency = fiat_currency
      @transactions = {}
    end

    def parse!(report)
      CSV.parse(report, headers: true).each do |row|
        next unless row[SOURCE] == 'Coinbase'

        case row[TYPE]
        when 'Reward'
          parse_reward!(row)
        end
      end
      transactions
    end

    private

    def parse_reward!(row)
      transaction = init_transaction(row)
      transaction.type = 'reward'
      transaction.from_currency = transaction.to_currency = Currency.by_symbol(row[ACQUIRED_ASSET])
      transaction.from_amount = transaction.to_amount = BigDecimal(row[ACQUIRED_AMOUNT])
      transaction.market_value_currency = fiat_currency
      transaction.market_value = BigDecimal(row[COST])
    end

    def init_transaction(row)
      trade_id = row[TRADE_ID]
      raise "trade_id: #{trade_id} already exist: #{row.inspect}" if @transactions.key?(trade_id)

      @transactions[trade_id] = Transaction.new(
        account:,
        platform_transaction_id: trade_id,
        completed_at: Time.parse(row[TIME])
      )
    end
  end
end