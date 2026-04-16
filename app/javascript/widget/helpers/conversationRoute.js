import { CONVERSATION_STATUS } from 'shared/constants/messages';

/**
 * True when the contact has a conversation that is not resolved (open, pending, or snoozed).
 */
export function isOngoingConversation(conversationParams) {
  if (!conversationParams) return false;
  const { id, status } = conversationParams;
  if (id === '' || id === null || id === undefined) return false;
  if (!status) return false;
  return status !== CONVERSATION_STATUS.RESOLVED;
}
