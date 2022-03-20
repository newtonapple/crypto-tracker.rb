# frozen_string_literal: true

require 'openssl'
require 'base64'

module CoinbaseExchange
  class Signature
    def self.from_env
      new(
        key: ENV['COINBASEPRO_API_KEY'],
        secret: ENV['COINBASEPRO_API_SECRET'],
        passphrase: ENV['COINBASEPRO_API_PASSPHRASE']
      )
    end

    def initialize(key:, secret:, passphrase:)
      @key = key
      @secret = Base64.decode64(secret)
      @passphrase = passphrase
    end

    def sign(method:, path:, body:, timestamp: Time.now.utc)
      ts = timestamp.to_i.to_s
      headers = {
        'cb-access-key': @key,
        'cb-access-passphrase': @passphrase,
        'cb-access-timestamp': ts
      }
      headers['cb-access-sign'] = hmac(ts + method + path + body)
      # s = hmac(ts + method + path + body)
      # headers['cb-access-sign'] = s
      headers
    end

    private

    def hmac(data)
      hmac = OpenSSL::HMAC.new(@secret, OpenSSL::Digest.new('SHA256'))
      hmac << data
      Base64.strict_encode64(hmac.digest)
      # Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', @secret, data))
    end
  end
end
