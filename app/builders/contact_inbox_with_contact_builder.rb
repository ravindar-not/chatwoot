# This Builder will create a contact and contact inbox with specified attributes.
# If an existing identified contact exisits, it will be returned.
# for contact inbox logic it uses the contact inbox builder

class ContactInboxWithContactBuilder
  pattr_initialize [:inbox!, :contact_attributes!, :source_id, :hmac_verified]

  def perform
    find_or_create_contact_and_contact_inbox
  # in case of race conditions where contact is created by another thread
  # we will try to find the contact and create a contact inbox
  rescue ActiveRecord::RecordNotUnique
    find_or_create_contact_and_contact_inbox
  end

  def find_or_create_contact_and_contact_inbox
    @contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id) if source_id.present?
    return @contact_inbox if @contact_inbox

    ActiveRecord::Base.transaction(requires_new: true) do
      build_contact_with_contact_inbox
    end
    update_contact_avatar(@contact) unless @contact.avatar.attached?
    @contact_inbox
  end

  private

  def build_contact_with_contact_inbox
    @contact = find_contact || create_contact
    @contact_inbox = create_contact_inbox
  end

  def account
    @account ||= inbox.account
  end

  def create_contact_inbox
    ContactInboxBuilder.new(
      contact: @contact,
      inbox: @inbox,
      source_id: @source_id,
      hmac_verified: hmac_verified
    ).perform
  end

  def update_contact_avatar(contact)
    ::Avatar::AvatarFromUrlJob.perform_later(contact, contact_attributes[:avatar_url]) if contact_attributes[:avatar_url]
  end

  def create_contact
    account.contacts.create!(
      name: contact_name_for_new_contact,
      phone_number: contact_attributes[:phone_number],
      email: contact_attributes[:email],
      identifier: contact_attributes[:identifier],
      additional_attributes: contact_attributes[:additional_attributes],
      custom_attributes: contact_attributes[:custom_attributes]
    )
  end

  def contact_name_for_new_contact
    name = contact_attributes[:name]
    return name if name.present?
    return '' if skip_random_contact_display_name?

    ::Haikunator.haikunate(1000)
  end

  # No Haikunator when the widget will collect identity via pre-chat (channel toggle and/or enabled fields).
  def skip_random_contact_display_name?
    return false unless inbox.web_widget?

    channel = inbox.channel
    return true if channel.pre_chat_form_enabled
    return true if pre_chat_form_has_enabled_fields?(channel)

    false
  end

  def pre_chat_form_has_enabled_fields?(channel)
    opts = channel.pre_chat_form_options
    return false if opts.blank?

    fields = opts.with_indifferent_access[:pre_chat_fields]
    return false if fields.blank?

    Array.wrap(fields).any? do |field|
      field.is_a?(Hash) && field.with_indifferent_access[:enabled]
    end
  end

  def find_contact
    contact = find_contact_by_identifier(contact_attributes[:identifier])
    contact ||= find_contact_by_email(contact_attributes[:email])
    contact ||= find_contact_by_phone_number(contact_attributes[:phone_number])
    contact ||= find_contact_by_instagram_source_id(source_id) if instagram_channel?

    contact
  end

  def instagram_channel?
    inbox.channel_type == 'Channel::Instagram'
  end

  # There might be existing contact_inboxes created through Channel::FacebookPage
  # with the same Instagram source_id. New Instagram interactions should create fresh contact_inboxes
  # while still reusing contacts if found in Facebook channels so that we can create
  # new conversations with the same contact.
  def find_contact_by_instagram_source_id(instagram_id)
    return if instagram_id.blank?

    existing_contact_inbox = ContactInbox.joins(:inbox)
                                         .where(source_id: instagram_id)
                                         .where(
                                           'inboxes.channel_type = ? AND inboxes.account_id = ?',
                                           'Channel::FacebookPage',
                                           account.id
                                         ).first

    existing_contact_inbox&.contact
  end

  def find_contact_by_identifier(identifier)
    return if identifier.blank?

    account.contacts.find_by(identifier: identifier)
  end

  def find_contact_by_email(email)
    return if email.blank?

    account.contacts.from_email(email)
  end

  def find_contact_by_phone_number(phone_number)
    return if phone_number.blank?

    account.contacts.find_by(phone_number: phone_number)
  end
end
