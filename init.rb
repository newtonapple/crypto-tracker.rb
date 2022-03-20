# frozen_string_literal: true

dev = ENV['RACK_ENV'] == 'development'

if dev
  require 'logger'
  logger = Logger.new($stdout)
end

require 'rack/unreloader'
Unreloader = Rack::Unreloader.new(subclasses: %w[Roda Sequel::Model], logger:, reload: dev) { RbCryptoTracker }

require_relative 'models'
