require 'rails_helper'

describe ContactInboxWithContactBuilder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, email: 'xyc@example.com', phone_number: '+23423424123', account: account, identifier: '123') }
  let(:existing_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  describe '#perform' do
    it 'doesnot create contact if it already exist with source id' do
      contact_inbox = described_class.new(
        source_id: existing_contact_inbox.source_id,
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'creates contact if contact doesnot exist with source id' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: 'testemail@example.com',
          custom_attributes: { test: 'test' }
        }
      ).perform

      expect(contact_inbox.contact.id).not_to eq(contact.id)
      expect(contact_inbox.contact.name).to eq('Contact')
      expect(contact_inbox.contact.custom_attributes).to eq({ 'test' => 'test' })
      expect(contact_inbox.inbox_id).to eq(inbox.id)
    end

    it 'doesnot create contact if it already exist with identifier' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          identifier: contact.identifier,
          phone_number: contact.phone_number,
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact if it already exist with email' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: contact.email
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact when an uppercase email is passed for an already existing contact email' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: contact.email.upcase
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact if it already exist with phone number' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: contact.phone_number,
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'reuses contact if it exists with the same source_id in a Facebook inbox when creating for Instagram inbox' do
      instagram_source_id = '123456789'

      # Create a Facebook page inbox with a contact using the same source_id
      facebook_inbox = create(:inbox, channel_type: 'Channel::FacebookPage', account: account)
      facebook_contact = create(:contact, account: account)
      facebook_contact_inbox = create(:contact_inbox, contact: facebook_contact, inbox: facebook_inbox, source_id: instagram_source_id)

      # Create an Instagram inbox
      instagram_inbox = create(:inbox, channel_type: 'Channel::Instagram', account: account)

      # Try to create a contact inbox with same source_id for Instagram
      contact_inbox = described_class.new(
        source_id: instagram_source_id,
        inbox: instagram_inbox,
        contact_attributes: {
          name: 'Instagram User',
          email: 'instagram_user@example.com'
        }
      ).perform

      # Should reuse the existing contact from Facebook
      expect(contact_inbox.contact.id).to eq(facebook_contact.id)
      # Make sure the contact inbox is not the same as the Facebook contact inbox
      expect(contact_inbox.id).not_to eq(facebook_contact_inbox.id)
      expect(contact_inbox.inbox_id).to eq(instagram_inbox.id)
    end

    it 'creates contact with blank name when web widget has pre-chat form enabled' do
      channel = create(:channel_widget, account: account, pre_chat_form_enabled: true)
      inbox = channel.inbox

      contact_inbox = described_class.new(
        source_id: SecureRandom.uuid,
        inbox: inbox,
        contact_attributes: {
          additional_attributes: {}
        }
      ).perform

      expect(contact_inbox.contact.name).to eq('')
    end

    it 'uses random name for web widget when pre-chat form is disabled' do
      channel = create(:channel_widget, account: account, pre_chat_form_enabled: false)
      inbox = channel.inbox

      contact_inbox = described_class.new(
        source_id: SecureRandom.uuid,
        inbox: inbox,
        contact_attributes: {
          additional_attributes: {}
        }
      ).perform

      expect(contact_inbox.contact.name).to be_present
    end

    it 'creates contact with blank name when pre-chat fields are enabled even if channel toggle is false' do
      channel = create(:channel_widget, account: account, pre_chat_form_enabled: false)
      channel.update!(
        pre_chat_form_options: {
          'pre_chat_message' => 'Hi',
          'pre_chat_fields' => [
            { 'name' => 'fullName', 'enabled' => true, 'field_type' => 'standard', 'type' => 'text', 'required' => false }
          ]
        }
      )
      inbox = channel.inbox

      contact_inbox = described_class.new(
        source_id: SecureRandom.uuid,
        inbox: inbox,
        contact_attributes: {
          additional_attributes: {}
        }
      ).perform

      expect(contact_inbox.contact.name).to eq('')
    end

    it 'uses provided name for web widget when pre-chat form is enabled' do
      channel = create(:channel_widget, account: account, pre_chat_form_enabled: true)
      inbox = channel.inbox

      contact_inbox = described_class.new(
        source_id: SecureRandom.uuid,
        inbox: inbox,
        contact_attributes: {
          name: 'Jane Doe',
          additional_attributes: {}
        }
      ).perform

      expect(contact_inbox.contact.name).to eq('Jane Doe')
    end
  end
end
