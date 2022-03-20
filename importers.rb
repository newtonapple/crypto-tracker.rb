# frozen_string_literal: true

module Importers
end

unless defined?(Unreloader)
  require 'rack/unreloader'
  Unreloader = Rack::Unreloader.new(reload: false)
end

Unreloader.require('importers/*.rb')
