# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
require_relative '../../models'
raise "test database doesn't end with test" unless DB.opts[:database].ends_with?('test')

require_relative '../minitest_helper'
