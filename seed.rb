# frozen_string_literal: true

require 'oj'
require_relative 'init'
Sequel::Model.plugin :update_or_create

class Platform
  def self.static_cache_allow_modifications?
    true
  end
end

class Currency
  def self.static_cache_allow_modifications?
    true
  end
end

class Seed
  # rubocop:disable Metrics
  def self.run!
    DB.transaction do
      seed = new
      seed.platforms(
        [
          ['Unknown',  nil],
          ['BlockFi',  'https://www.blockfi.com'],
          ['Coinbase', 'https://www.coinbase.com'],
          ['Coinbase Pro', 'https://pro.coinbase.com'],
          ['Coinbase Wallet', 'https://www.coinbase.com/wallet'],
          ['Gemini', 'https://www.gemini.com/'],
          ['Gemini Earn', 'https://www.gemini.com/earn'],
          ['MetaMask', 'https://metamask.io/'],
          ['Voyager', 'https://www.investvoyager.com/']
        ]
      )

      fiats = Oj.load(File.read('seed/fiats.json')).map { |c| [c['name'], c['symbol'], 'fiat'] }
      cryptos = Oj.load(File.read('seed/cryptos.json')).map { |c| [c['name'], c['symbol'], 'crypto'] }
      seed.currencies(fiats)
      seed.currencies(cryptos)
    end

    Platform.load_cache
    Currency.load_cache
    puts "Platform.count: #{Platform.count}"
    puts "Currency.count: #{Currency.count}"
  end
  # rubocop:enable Metrics

  def platforms(platforms)
    platforms.map do |platform|
      name = platform[0]
      url = platform[1]
      Platform.update_or_create({ name: }, url:)
    end
  end

  def currencies(currencies)
    currencies.map do |currency|
      name = currency[0]
      symbol = currency[1]
      type = currency[2]
      Currency.update_or_create(name:, symbol:, type:)
    end
  end
end
