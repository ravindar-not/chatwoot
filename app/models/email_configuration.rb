# frozen_string_literal: true

# Polymorphic outbound email settings (from, subject, optional body) for configurable records (e.g. Inbox).
class EmailConfiguration < ApplicationRecord
  belongs_to :configurable, polymorphic: true

  validates :configurable_id, uniqueness: { scope: :configurable_type }
  validates :configurable_type, presence: true
end
