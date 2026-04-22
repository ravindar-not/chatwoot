/**
 * Pre-chat field list after hiding fields we already know from the contact
 * (same rules as PreChat/Form.vue filteredPreChatFields).
 *
 * @param {Array} preChatFields - from preChatFormOptions.preChatFields
 * @param {object} [currentUser] - from contacts/getCurrentUser
 * @returns {Array}
 */
export function filterPreChatFieldsByKnownContact(
  preChatFields,
  currentUser = {}
) {
  if (!Array.isArray(preChatFields) || !preChatFields.length) {
    return [];
  }
  const isUserEmailAvailable = !!currentUser.has_email;
  const isUserPhoneNumberAvailable = !!currentUser.has_phone_number;
  const isUserIdentifierAvailable = !!currentUser.identifier;
  const isUserNameAvailable = !!(
    isUserIdentifierAvailable ||
    isUserEmailAvailable ||
    isUserPhoneNumberAvailable ||
    currentUser.has_name
  );
  return preChatFields.filter(field => {
    if (isUserEmailAvailable && field.name === 'emailAddress') {
      return false;
    }
    if (isUserPhoneNumberAvailable && field.name === 'phoneNumber') {
      return false;
    }
    if (isUserNameAvailable && field.name === 'fullName') {
      return false;
    }
    return true;
  });
}
