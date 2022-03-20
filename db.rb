# frozen_string_literal: true

begin
  require_relative '.env'
rescue LoadError
end

require 'sequel/core'
# Delete RB_CRYPTO_TRACKER_DATABASE_URL from the environment, so it isn't accidently
# passed to subprocesses.  RB_CRYPTO_TRACKER_DATABASE_URL may contain passwords.
DB = Sequel.connect(ENV.delete('RB_CRYPTO_TRACKER_DATABASE_URL') || ENV.delete('DATABASE_URL'))
DB.extension :pg_enum
