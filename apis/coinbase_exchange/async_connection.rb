# frozen_string_literal: true

require 'async/http/faraday'

module CoinbaseExchange
  module AsyncConnection
    Faraday.default_adapter = :async_http

    def self.build(signature: CoinbaseExchange::Signature.from_env, url: 'https://api.exchange.coinbase.com')
      Faraday.new(url) do |f|
        f.use :cb_exchange, signature:
      end
    end
  end
end
