# frozen_string_literal: true

class RbCryptoTracker
  hash_branch('prefix1') do |_r|
    set_view_subdir 'prefix1'
  end
end
