# frozen_string_literal: true

class AddFourAyFieldsToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :four_ay_agent_id, :string
    add_column :inboxes, :four_ay_lookup_api_url, :text
    add_column :inboxes, :four_ay_db_verification_required, :boolean, default: false, null: false
  end
end
