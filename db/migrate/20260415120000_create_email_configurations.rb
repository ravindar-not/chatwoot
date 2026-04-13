# frozen_string_literal: true

class CreateEmailConfigurations < ActiveRecord::Migration[7.1]
  def change
    create_table :email_configurations do |t|
      t.string :configurable_type, null: false
      t.bigint :configurable_id, null: false
      t.string :mail_from
      t.string :mail_subject
      t.text :body

      t.timestamps
    end

    add_index :email_configurations, %i[configurable_type configurable_id], unique: true, name: 'index_email_configurations_on_configurable'
  end
end
