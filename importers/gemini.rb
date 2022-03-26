# frozen_string_literal: true

require 'csv'

module Importers
  # Importer for Gemini Transactions History CSVs
  class Gemini
    # Common row functionalities between Gemini & Gemini Earn
    module Row
      DATE     = 'Date'
      TIME     = 'Time (UTC)'
      TYPE     = 'Type'
      CURRENCY = 'Symbol'

      private

      def init_transaction(row)
        time = parse_time(row)
        tx_id = parse_tx_id(row, time)
        transaction = transactions[tx_id]
        return transaction if transaction

        transactions[tx_id] = Transaction.new(
          account:,
          platform_transaction_id: tx_id,
          completed_at: time
        )
      end

      def parse_transfer!(row, type)
        transaction = init_transaction(row)
        transaction.type = type
        currency = Currency.by_symbol(row[CURRENCY])
        amount = parse_amount(row, currency.symbol)
        transaction.from_currency = transaction.to_currency = currency
        transaction.from_amount = transaction.to_amount = amount
        transaction
      end

      def parse_time(row)
        return unless row[DATE] && row[TIME]

        Time.parse("#{row[DATE]} #{row[TIME]} UTC")
      end

      def parse_amount(row, symbol)
        amount = row[amount_header(symbol)]
        return unless amount

        parse_number(amount, symbol)
      end

      def parse_number(amount, symbol)
        sign = amount[0] == '(' ? -1 : 1
        sign * BigDecimal(amount.gsub(/[$, ()]|#{symbol}/, ''))
      end
    end

    include Row

    SPEC     = 'Specification'
    TRADE_ID = 'Trade ID'
    ORDER_ID = 'Order ID'
    TX_HASH  = 'Tx Hash'
    DEPOSIT_ADDRESS = 'Deposit Destination'
    WITHDRAW_ADDRESS = 'Withdrawal Destination'

    TRADE_TYPES = %w[Buy Sell].freeze

    # https://docs.gemini.com/rest-api/#symbols-and-minimums
    SYMBOLS = {
      'GUSDUSD' => %w[GUSD USD],
      'BTCUSD' => %w[BTC USD],
      'ETHBTC' => %w[ETH BTC],
      'ETHUSD' => %w[ETH USD],
      'ZECUSD' => %w[ZEC USD],
      'ZECBTC' => %w[ZEC BTC],
      'ZECETH' => %w[ZEC ETH],
      'ZECBCH' => %w[ZEC BCH],
      'ZECLTC' => %w[ZEC LTC],
      'BCHUSD' => %w[BCH USD],
      'BCHBTC' => %w[BCH BTC],
      'BCHETH' => %w[BCH ETH],
      'LTCUSD' => %w[LTC USD],
      'LTCBTC' => %w[LTC BTC],
      'LTCETH' => %w[LTC ETH],
      'LTCBCH' => %w[LTC BCH],
      'BATUSD' => %w[BAT USD],
      'DAIUSD' => %w[DAI USD],
      'LINKUSD' => %w[LINK USD],
      'OXTUSD' => %w[OXT USD],
      'BATBTC' => %w[BAT BTC],
      'LINKBTC' => %w[LINK BTC],
      'OXTBTC' => %w[OXT BTC],
      'BATETH' => %w[BAT ETH],
      'LINKETH' => %w[LINK ETH],
      'OXTETH' => %w[OXT ETH],
      'AMPUSD' => %w[AMP USD],
      'COMPUSD' => %w[COMP USD],
      'PAXGUSD' => %w[PAXG USD],
      'MKRUSD' => %w[MKR USD],
      'ZRXUSD' => %w[ZRX USD],
      'KNCUSD' => %w[KNC USD],
      'MANAUSD' => %w[MANA USD],
      'STORJUSD' => %w[STORJ USD],
      'SNXUSD' => %w[SNX USD],
      'CRVUSD' => %w[CRV USD],
      'BALUSD' => %w[BAL USD],
      'UNIUSD' => %w[UNI USD],
      'RENUSD' => %w[REN USD],
      'UMAUSD' => %w[UMA USD],
      'YFIUSD' => %w[YFI USD],
      'BTCDAI' => %w[BTC DAI],
      'ETHDAI' => %w[ETH DAI],
      'AAVEUSD' => %w[AAVE USD],
      'FILUSD' => %w[FIL USD],
      'BTCEUR' => %w[BTC EUR],
      'BTCGBP' => %w[BTC GBP],
      'ETHEUR' => %w[ETH EUR],
      'ETHGBP' => %w[ETH GBP],
      'BTCSGD' => %w[BTC SGD],
      'ETHSGD' => %w[ETH SGD],
      'SKLUSD' => %w[SKL USD],
      'GRTUSD' => %w[GRT USD],
      'BNTUSD' => %w[BNT USD],
      '1INCHUSD' => %w[1INCH USD],
      'ENJUSD' => %w[ENJ USD],
      'LRCUSD' => %w[LRC USD],
      'SANDUSD' => %w[SAND USD],
      'CUBEUSD' => %w[CUBE USD],
      'LPTUSD' => %w[LPT USD],
      'BONDUSD' => %w[BOND USD],
      'MATICUSD' => %w[MATIC USD],
      'INJUSD' => %w[INJ USD],
      'SUSHIUSD' => %w[SUSHI USD],
      'DOGEUSD' => %w[DOGE USD],
      'ALCXUSD' => %w[ALCX USD],
      'MIRUSD' => %w[MIR USD],
      'FTMUSD' => %w[FTM USD],
      'ANKRUSD' => %w[ANKR USD],
      'BTCGUSD' => %w[BTC GUSD],
      'ETHGUSD' => %w[ETH GUSD],
      'CTXUSD' => %w[CTX USD],
      'XTZUSD' => %w[XTZ USD],
      'AXSUSD' => %w[AXS USD],
      'SLPUSD' => %w[SLP USD],
      'LUNAUSD' => %w[LUNA USD],
      'USTUSD' => %w[UST USD],
      'MCO2USD' => %w[MCO2 USD],
      'DOGEBTC' => %w[DOGE BTC],
      'DOGEETH' => %w[DOGE ETH],
      'WCFGUSD' => %w[WCFG USD],
      'RAREUSD' => %w[RARE USD],
      'RADUSD' => %w[RAD USD],
      'QNTUSD' => %w[QNT USD],
      'NMRUSD' => %w[NMR USD],
      'MASKUSD' => %w[MASK USD],
      'FETUSD' => %w[FET USD],
      'ASHUSD' => %w[ASH USD],
      'AUDIOUSD' => %w[AUDIO USD],
      'API3USD' => %w[API3 USD],
      'USDCUSD' => %w[USDC USD],
      'SHIBUSD' => %w[SHIB USD],
      'RNDRUSD' => %w[RNDR USD],
      'MCUSD' => %w[MC USD],
      'GALAUSD' => %w[GALA USD],
      'ENSUSD' => %w[ENS USD],
      'KP3RUSD' => %w[KP3R USD],
      'CVCUSD' => %w[CVC USD],
      'ELONUSD' => %w[ELON USD],
      'MIMUSD' => %w[MIM USD],
      'SPELLUSD' => %w[SPELL USD],
      'TOKEUSD' => %w[TOKE USD],
      'LDOUSD' => %w[LDO USD],
      'RLYUSD' => %w[RLY USD],
      'SOLUSD' => %w[SOL USD],
      'RAYUSD' => %w[RAY USD],
      'SBRUSD' => %w[SBR USD],
      'APEUSD' => %w[APE USD]
    }.freeze

    attr_reader :account, :transactions

    def initialize(account:)
      @account = account
      @transactions = {}
    end

    def parse!(report)
      CSV.parse(report, headers: true).sort_by { |r| "#{r[DATE]}:#{r[TIME]}" }.each do |row|
        next unless row[DATE]

        next parse_trade!(row) if TRADE_TYPES.include?(row[TYPE])

        case row[SPEC]
        when 'Earn Redemption', /^Deposit \(#{row[CURRENCY]}\)/
          parse_transfer!(row, 'transfer_in')
        when 'Earn Transfer', /^Withdrawal \(#{row[CURRENCY]}\)/
          parse_transfer!(row, 'transfer_out')
        end
      end
      transactions
    end

    private

    def parse_trade!(row)
      transaction = init_transaction(row)
      c1, c2 = parse_currencies(row)
      transaction.set_amount!(c1, parse_amount(row, c1.symbol))
      transaction.set_amount!(c2, parse_amount(row, c2.symbol))
      set_fee(transaction, row)
      transaction.classify_trade!
    end

    def parse_transfer!(row, type)
      transaction = super
      set_fee(transaction, row)
    end

    def set_fee(transaction, row)
      fee_currency = transaction.from_currency
      fee = parse_fee(row, fee_currency.symbol)
      return unless fee&.positive?

      transaction.fee_currency = fee_currency
      transaction.fee = fee
    end

    def parse_tx_id(row, time)
      symbol = row[CURRENCY]
      type = row[TYPE]
      spec = row[SPEC]
      tx_id = [type, spec, symbol, time.to_i]

      trade_id = row[TRADE_ID]
      order_id = row[ORDER_ID]
      return tx_id.push(trade_id, order_id).join(':') if trade_id

      tx_hash = row[TX_HASH]
      return tx_id.concat([tx_hash, row[DEPOSIT_ADDRESS], row[WITHDRAW_ADDRESS]].compact).join(':') if tx_hash

      from, to = SYMBOLS[symbol]

      if from.nil?
        amount = row[amount_header(symbol)]
        fee = row[fee_header(symbol)]
        return tx_id.concat([tx_hash, amount, fee].compact).join(':')
      end

      from_amount = row[amount_header(from)]
      to_amount = row[amount_header(to)]
      from_fee = row[fee_header(from)]
      to_fee = row[fee_header(to)]
      tx_id.concat([tx_hash, from_amount, to_amount, from_fee, to_fee].compact).join(':')
    end

    def parse_currencies(row)
      symbol = row[CURRENCY]
      return unless symbol

      from, to = SYMBOLS[symbol]
      [Currency.by_symbol(from), Currency.by_symbol(to)]
    end

    def parse_fee(row, symbol)
      amount = row[fee_header(symbol)]
      return unless amount

      parse_number(amount, symbol)
    end

    def fee_header(symbol)
      "Fee (#{symbol} #{symbol})"
    end

    def amount_header(symbol)
      "#{symbol} Amount #{symbol}"
    end
  end
end
