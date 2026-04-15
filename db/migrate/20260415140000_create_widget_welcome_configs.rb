# frozen_string_literal: true

class CreateWidgetWelcomeConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :widget_welcome_configs do |t|
      t.references :inbox, null: false, foreign_key: true, index: { unique: true }
      t.text :main_heading
      t.text :second_heading
      t.jsonb :suggested_queries, null: false, default: []

      t.timestamps
    end
  end
end
