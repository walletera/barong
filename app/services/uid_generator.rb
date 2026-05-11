# frozen_string_literal: true

class UIDGenerator
  def self.generate(_ = nil)
    SecureRandom.uuid
  end
end
