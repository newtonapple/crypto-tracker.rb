# frozen_string_literal: true

require_relative 'gemini'

module Importers
  # Importer for Gemini Transactions History CSVs
  class GeminiEarn
    include Gemini::Row

    attr_reader :account, :fiat_currency, :transactions

    def initialize(account:, fiat_currency: Currency.by_symbol('USD'))
      @account = account
      @fiat_currency = fiat_currency
      @price_header = price_header(fiat_currency.symbol)
      @transactions = {}
    end

    def parse!(report)
      CSV.parse(report, headers: true).sort_by { |r| "#{r[DATE]}:#{r[TIME]}" }.each do |row|
        next unless row[DATE]

        case row[TYPE]
        when 'Interest Credit'
          parse_interest!(row)
        when 'Deposit'
          parse_row!(row, 'transfer_in')
        when 'Redeem'
          parse_row!(row, 'transfer_out')
        end
      end
      transactions
    end

    private

    def parse_interest!(row)
      return unless row[@price_header]

      transaction = parse_row!(row, 'interest')
      price = parse_price(row)
      transaction.market_value_currency = fiat_currency
      transaction.market_value = price * transaction.to_amount
    end

    def parse_row!(row, type)
      transaction = init_transaction(row)
      transaction.type = type

      currency = Currency.by_symbol(row[CURRENCY])
      amount = parse_amount(row, currency.symbol)
      transaction.from_currency = transaction.to_currency = currency
      transaction.from_amount = transaction.to_amount = amount
      transaction
    end

    def parse_tx_id(row, time)
      symbol = row[CURRENCY]
      type = row[TYPE]
      [
        type,
        symbol,
        fiat_currency.symbol,
        time.to_i,
        row[amount_header(symbol)],              # amount
        row[amount_header(fiat_currency.symbol)] # fiat amount
      ].compact.join(':')
    end

    def parse_price(row)
      price = row[@price_header]
      return unless price

      parse_number(price, fiat_currency.symbol)
    end

    def amount_header(symbol)
      "Amount #{symbol}"
    end

    def price_header(symbol)
      "Price #{symbol}"
    end
  end
end
