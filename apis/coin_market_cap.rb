# frozen_string_literal: true

require 'oj'
require 'async/http/faraday'

module CoinMarketCap
  COINMARKETCAP_CRYPTOS = Oj.load(File.read(File.join(__dir__, '../seed/cryptos.json')))

  class << self
    API_URL        = 'https://api.coinmarketcap.com'
    QUOTE_ENDPOINT = 'data-api/v3/cryptocurrency/historical'
    USD_ID         = 2781
    REQUEST_HEADER = {
      Accepts: 'application/json'
    }.freeze

    def connection
      Faraday.new(url: API_URL, headers: REQUEST_HEADER)
    end

    def quotes(symbol:, from:, to:, connection: self.connection)
      params = {
        id: find_id_by_symbol(symbol),
        convertId: USD_ID, # USD
        timeStart: from,
        timeEnd: to
      }
      resp = connection.get(QUOTE_ENDPOINT, params)
      Oj.load(resp.body)['data']
    end

    def find_id_by_symbol(symbol)
      find_by_symbol(symbol)['id']
    end

    def find_by_symbol(symbol)
      COINMARKETCAP_CRYPTOS.find { |crypto| crypto['symbol'] == symbol }
    end
  end
end
