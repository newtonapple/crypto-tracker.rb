# frozen_string_literal: true

require 'faraday'
require 'oj'

module CoinbaseExchange
  module FaradayMiddleware
    class Api < Faraday::Middleware
      def initialize(app = nil, options = {})
        super(app, options)
        @options = options
        @signature = options[:signature]
      end

      def on_request(env)
        timestamp = env[:timestamp] || Time.now.utc
        env.request_headers.merge!(
          @signature.sign(
            method: env.method.to_s.upcase,
            path: signature_url_query(env.url),
            body: signature_body(env.request_body),
            timestamp:
          )
        )
      end

      def on_complete(env)
        body = env[:body]
        env[:body] = Oj.load(body) unless body.empty?
      end

      private

      def signature_url_query(url)
        query = url.query
        query.nil? || query.empty? ? url.path : "#{url.path}?#{query}"
      end

      def signature_body(body)
        body || ''
      end
    end

    class JsonResponse < Faraday::Middleware
    end
  end
end

Faraday::Middleware.register_middleware(cb_exchange: CoinbaseExchange::FaradayMiddleware::Api)
