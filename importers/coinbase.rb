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
    COST            = 'Cost Basis (incl. fees and/or spread) (USD)'
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
        case row[TYPE]
        when 'Deposit' # internal transfer from Coinbase Pro
          parse_transaction!(row, 'transfer_in')
        when 'Receive' # transfer external source
          parse_transaction!(row, 'transfer_in')
        when 'Reward', 'Rewards'
          parse_reward!(row)
          # when 'Stake' # e.g. ADA
          #   we ignore stake for now as cryptos are still in our account
          #  when 'Untake' # e.g. ADA
          #   we ignore unstake for now as cryptos are still in our account
        end
      end
      transactions
    end

    private

    def parse_reward!(row)
      transaction = parse_transaction!(row, 'reward')
      transaction.market_value_currency = fiat_currency
      transaction.market_value = BigDecimal(row[COST])
    end

    def parse_transaction!(row, type)
      transaction = init_transaction(row)
      transaction.type = type
      transaction.from_currency = transaction.to_currency = Currency.by_symbol(row[ACQUIRED_ASSET])
      transaction.from_amount = transaction.to_amount = BigDecimal(row[ACQUIRED_AMOUNT])
      transaction
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
