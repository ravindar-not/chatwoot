# frozen_string_literal: true

class WidgetWelcomeConfig < ApplicationRecord
  belongs_to :inbox

  before_validation :nilify_blank_headings
  before_validation :normalize_suggested_queries

  validate :inbox_must_be_web_widget
  validate :suggested_queries_format

  private

  def nilify_blank_headings
    self.main_heading = main_heading.presence
    self.second_heading = second_heading.presence
  end

  def inbox_must_be_web_widget
    return if inbox.blank?

    errors.add(:inbox, :invalid) unless inbox.web_widget?
  end

  def suggested_queries_format
    return unless suggested_queries.is_a?(Array)

    suggested_queries.each do |entry|
      next if entry.is_a?(Hash) && entry['message'].present?

      errors.add(:suggested_queries, :invalid)
      break
    end
  end

  def normalize_suggested_queries
    unless suggested_queries.is_a?(Array)
      self.suggested_queries = []
      return
    end

    self.suggested_queries = suggested_queries.filter_map do |entry|
      next unless entry.is_a?(Hash)

      h = entry.stringify_keys
      label = h['label'].to_s.strip
      message = h['message'].to_s.strip
      next if message.blank?

      { 'label' => (label.presence || message), 'message' => message }
    end
  end
end
