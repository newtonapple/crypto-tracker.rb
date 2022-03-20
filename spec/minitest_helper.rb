# frozen_string_literal: true

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'
require 'minitest/hooks/default'

module Minitest
  class HooksSpec
    around(:all) do |&block|
      DB.transaction(rollback: :always) { super(&block) }
    end

    around do |&block|
      DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) { super(&block) }
    end

    def log
      LOGGER.level = Logger::INFO
      yield
    ensure
      LOGGER.level = Logger::FATAL
    end
  end
end
