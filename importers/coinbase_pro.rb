# frozen_string_literal: true

require 'csv'

module Importers
  # Importer for Coinbase Exchange API
  class CoinbasePro
    TYPE = 'type'
    TIME = 'time'
    AMOUNT = 'amount'
    CURRENCY = 'amount/balance unit'
    TRADE_ID = 'trade id'
    ORDER_ID = 'order id'
    TRANSFER_ID = 'transfer id'

    attr_reader :account, :transactions

    def initialize(account:)
      @account = account
      @transactions = {}
    end

    def parse!(report)
      CSV.parse(report, headers: true).each do |row|
        case row[TYPE]
        when 'match'
          parse_match!(row)
        when 'fee'
          parse_fee!(row)
        when 'conversion'
          parse_conversion!(row)
        when 'deposit'
          parse_transfer!(row, 'transfer_in')
        when 'withdrawal'
          parse_transfer!(row, 'transfer_out')
        end
      end
      transactions
    end

    def fill_exchange_fees!(async_connection = CoinbaseExchange::AsyncConnection.build)
      orders = Hash.new { |h, k| h[k] = {} }
      transactions.each_value do |t|
        next unless t.type == 'exchange'

        order_id, trade_id = t.platform_transaction_id.split(':')
        next unless order_id && trade_id

        orders[order_id][trade_id] = t
      end
      fetch_market_values_from_fills(async_connection, orders)
    end

    private

    def fetch_market_values_from_fills(conn, orders, batch_size = 3)
      usd = Currency.by_symbol('USD')
      orders.keys.each_slice(batch_size) do |order_ids|
        Async do |task|
          order_ids.each do |order_id|
            task.async do
              conn.get('/fills', limit: 100, order_id:).body.each do |fill|
                next unless fill['settled']

                transaction = orders[order_id][fill['trade_id'].to_s]
                next unless transaction

                transaction.market_value = BigDecimal(fill['usd_volume'])
                transaction.market_value_currency = usd
              end
            end
          end
        end
      end
    end

    def parse_conversion!(row)
      time = Time.parse(row[TIME])
      tx_id = "conversion:#{time.to_i}"
      transaction = @transactions[tx_id] ||= Transaction.new(
        account: @account,
        platform_transaction_id: "#{@account.id}:#{tx_id}",
        completed_at: time
      )
      transaction.set_amount!(Currency.by_symbol(row[CURRENCY]), BigDecimal(row[AMOUNT]))
      transaction.classify_trade!
    end

    def parse_transfer!(row, type)
      tx_id = row[TRANSFER_ID]
      return unless tx_id

      currency = Currency.by_symbol(row[CURRENCY])
      return unless currency&.crypto?

      amount = BigDecimal(row[AMOUNT])
      transactions[tx_id] = Transaction.new(
        account: @account,
        from_currency: currency,
        from_amount: amount,
        to_currency: currency,
        to_amount: amount,
        type:,
        platform_transaction_id: tx_id,
        completed_at: Time.parse(row[TIME])
      )
    end

    def parse_match!(row)
      transaction = init_trade(row)
      transaction.set_amount!(Currency.by_symbol(row[CURRENCY]), BigDecimal(row[AMOUNT]))
      transaction.classify_trade!
    end

    def parse_fee!(row)
      transaction = init_trade(row)
      transaction.fee_currency = Currency.by_symbol(row[CURRENCY])
      transaction.fee = BigDecimal(row[AMOUNT])
    end

    def init_trade(row)
      tx_id = trade_id = row[TRADE_ID]
      @transactions[tx_id] ||= Transaction.new(
        account: @account,
        platform_transaction_id: "#{row[ORDER_ID]}:#{trade_id}",
        completed_at: Time.parse(row[TIME])
      )
    end
  end
end
