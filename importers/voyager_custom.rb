# frozen_string_literal: true

require 'csv'
require 'oj'

module Importers
  # Importer for Voyager Tax/Transactions CSV from https://research.investvoyager.com/tax/
  # (default Voyager format)
  class VoyagerCustom
    TIME      = 'transaction_date'
    AMOUNT    = 'quantity'
    CURRENCY  = 'base_asset'
    PRICE     = 'price'
    TRADE_ID  = 'transaction_id'
    TYPE      = 'transaction_type'
    DIRECTION = 'transaction_direction'

    attr_reader :account, :fiat_currency, :transactions

    def initialize(account:, fiat_currency: Currency.by_symbol('USD'))
      @account = account
      @fiat_currency = fiat_currency
      @transactions = {}
    end

    def parse!(report)
      CSV.parse(report, headers: true).sort_by { |r| r[TIME] }.each do |row|
        case row[TYPE]
        when 'TRADE', 'Fiat Buy', 'Fiat Sell'
          parse_trade!(row)
        when 'INTEREST', 'Interest Income'
          parse_income!(row, 'interest')
        when 'ADMIN', 'REWARD', 'Income'
          parse_income!(row, 'reward')
        when 'BLOCKCHAIN'
          parse_transfer!(row)
        when 'Withdrawal'
          parse_withdraw!(row)
        when 'Withdrawal Fee'
          parse_withdraw_fee!(row)
        end
      end
      transactions
    end

    private

    def parse_trade!(row)
      transaction = init_transaction(row)
      transaction.type = row[DIRECTION].downcase
      crypto_currency, amount, fiat_amount = parse_row(row)

      if transaction.type == 'buy'
        transaction.from_currency = fiat_currency
        transaction.from_amount = -fiat_amount
        transaction.to_currency = crypto_currency
        transaction.to_amount = amount
      elsif transaction.type == 'sell'
        transaction.from_currency = crypto_currency
        transaction.from_amount = -amount
        transaction.to_currency = fiat_currency
        transaction.to_amount = fiat_amount
      else
        raise "unknown transaction type: #{transaction.type}: #{row.inspect}"
      end
    end

    def parse_income!(row, type)
      transaction = init_transaction(row)
      transaction.type = type
      crypto_currency, amount, fiat_amount = parse_row(row)
      transaction.to_currency = transaction.from_currency = crypto_currency
      transaction.to_amount = transaction.from_amount = amount
      transaction.market_value_currency = fiat_currency
      transaction.market_value = fiat_amount
    end

    def parse_transfer!(row)
      transaction = init_transaction(row)
      crypto_currency, amount, = parse_row(row) # don't care about quote fiat_price

      case row[DIRECTION]
      when 'deposit'
        transaction.type = 'transfer_in'
        transaction.to_currency = transaction.from_currency = crypto_currency
        transaction.to_amount = transaction.from_amount = amount
      when /^withdraw/ # this has not be tested
        transaction.type = 'transfer_out'
        transaction.to_currency = transaction.from_currency = crypto_currency
        transaction.to_amount = transaction.from_amount = -amount
      else
        raise "unknown transfer type: #{row[DIRECTION]}: #{row.inspect}"
      end
    end

    def parse_withdraw!(row)
      return if Currency.by_symbol(row[CURRENCY]).fiat? # ignore fiat withdraws

      transaction = init_transaction(row)
      crypto_currency, amount, = parse_row(row) # don't care about quote fiat_price
      transaction.type = 'transfer_out'
      transaction.to_currency = transaction.from_currency = crypto_currency
      transaction.to_amount = transaction.from_amount = amount # amount is already negative
    end

    def parse_withdraw_fee!(row)
      transfer = init_transaction(row)
      fee_currency, amount, = parse_row(row) # don't care about quote fiat_price

      raise "withdraw fee currency mismatched: from_currency: #{transfer.from_currency}, to_currency: #{transfer.to_currency}" if transfer.from_currency != fee_currency

      transfer.fee_currency = fee_currency
      transfer.fee = amount # amount is already negative

      # transferrred amount already had fee taken out of it, so we have to add it back into the amount in order to match our internal format
      transfer.to_amount = transfer.from_amount = transfer.from_amount + amount
    end

    def parse_row(row)
      crypto_currency = Currency.by_symbol(row[CURRENCY])
      amount = BigDecimal(row[AMOUNT])
      price = BigDecimal(row[PRICE]) # price is always in fiat (USD)
      fiat_amount = amount * price
      [crypto_currency, amount, fiat_amount]
    end

    def init_transaction(row)
      trade_id = row[TRADE_ID]
      raise "trade_id: #{trade_id} already exist: #{row.inspect}" if @transactions.key?(trade_id) && row[TYPE] != 'Withdrawal Fee'

      @transactions[trade_id] ||= Transaction.new(
        account: @account,
        platform_transaction_id: trade_id,
        completed_at: row[TIME] # local time
      )
    end
  end
end
