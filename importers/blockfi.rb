# frozen_string_literal: true

require 'csv'
require 'set'

module Importers
  # Importer for BlockFi
  class BlockFi
    TYPE = 'Transaction Type'
    TIME = 'Confirmed At'
    AMOUNT = 'Amount'
    CURRENCY = 'Cryptocurrency'

    DOLLAR_PEGGED_COINS = Set.new(%w[USDC BUSD PAX GUSD]).freeze # NOTE: DAI is not pegged to USD on BlockFi

    attr_reader :account, :fiat_currency, :transactions

    def initialize(account:, fiat_currency: Currency.by_symbol('USD'))
      @account = account
      @fiat_currency = fiat_currency
      @trade_transactions = {}
      @transactions = []
    end

    def parse!(report)
      ## BlockFi Transaction Types
      # Internal Transfer - BIA
      # Internal Transfer - Wallet
      # Interest Payment
      # Crypto Transfer
      # ACH Return
      # ACH Transfer
      # ACH Withdrawal Return
      # Wire Transfer
      # Referral Payment
      # Bonus Payment
      # Trade
      # TLH Trade
      # ACH Trade
      # ACH Trade Return
      # Credit Card
      # Credit Card Rewards
      # Credit Card Trading Rebate
      # Credit Card Referral Bonus
      # Credit Card Stablecoin Boost
      csv = CSV.parse(report, headers: true).sort_by { |r| r[TIME] || '' }
      csv.each do |row|
        next unless row[TIME]

        case row[TYPE]
        when /Trade$/
          parse_trade!(row)
        when 'Ach Deposit' # fiat to crypto
          parse_buy!(row)
        when 'Ach Withdrawal' # # crypto to fiat
          parse_sell!(row)
        when 'Cc Rewards Redemption', 'Cc Trading Rebate'
          parse_crypto_transaction!(row, 'refund')
        when 'Interest Payment'
          parse_crypto_transaction!(row, 'interest')
        when 'Crypto Transfer'
          parse_crypto_transaction!(row, 'transfer_in')
        when 'Withdrawal'
          parse_crypto_transaction!(row, 'transfer_out')
        end
      end
      transactions
    end

    private

    def parse_buy!(row)
      transaction = init_transaction(row)
      amount = BigDecimal(row[AMOUNT])
      transaction.type = 'buy'
      transaction.from_currency = fiat_currency
      transaction.from_amount = amount
      transaction.to_currency = Currency.by_symbol(row[CURRENCY])
      transaction.to_amount = amount
    end

    def parse_sell!(row)
      transaction = init_transaction(row)
      amount = BigDecimal(row[AMOUNT])
      currency = Currency.by_symbol(row[CURRENCY])
      transaction.type = 'sell'
      transaction.from_currency = currency
      transaction.from_amount = amount

      return unless DOLLAR_PEGGED_COINS.include?(currency)

      transaction.to_currency = fiat_currency
      transaction.to_amount = amount.abs
    end

    def parse_crypto_transaction!(row, type)
      transaction = init_transaction(row)
      currency = Currency.by_symbol(row[CURRENCY])
      return unless currency&.crypto?

      amount = BigDecimal(row[AMOUNT])
      transaction.from_currency = currency
      transaction.from_amount = amount
      transaction.to_currency = currency
      transaction.to_amount = amount
      transaction.type = type
    end

    # each trade contains 2 rows in the CSV
    # one row for buy and one row for sell
    def parse_trade!(row)
      transaction = init_trade(row)
      transaction.set_amount!(Currency.by_symbol(row[CURRENCY]), BigDecimal(row[AMOUNT]))
      transaction.classify_trade!
      infer_market_value(transaction)
    end

    def infer_market_value(transaction)
      return if transaction.type != 'exchange'

      if dollar_pegged_coin?(transaction.from_currency)
        transaction.market_value = transaction.from_amount.abs
        transaction.market_value_currency = fiat_currency
      elsif dollar_pegged_coin?(transaction.to_currency)
        transaction.market_value = transaction.to_amount
        transaction.market_value_currency = fiat_currency
      end
    end

    def init_trade(row)
      completed_at = Time.parse(row[TIME])
      platform_transaction_id = "#{row[TYPE]}:#{completed_at.to_i}"

      transation = @trade_transactions[platform_transaction_id]
      return transation if transation

      transaction = Transaction.new(account:, platform_transaction_id:, completed_at:)
      @trade_transactions[platform_transaction_id] = transaction
      @transactions << transaction
      transaction
    end

    def init_transaction(row)
      completed_at = Time.parse(row[TIME])
      platform_transaction_id = "#{row[TYPE]}:#{completed_at.to_i}:#{row[CURRENCY]}:#{row[AMOUNT]}"
      transaction = Transaction.new(account:, platform_transaction_id:, completed_at:)
      @transactions << transaction
      transaction
    end

    def dollar_pegged_coin?(currency)
      DOLLAR_PEGGED_COINS.include?(currency.symbol)
    end
  end
end
