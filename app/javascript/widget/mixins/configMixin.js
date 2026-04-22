import { mapGetters } from 'vuex';
import { filterPreChatFieldsByKnownContact } from 'widget/helpers/preChatForm';

export default {
  computed: {
    ...mapGetters({
      currentUser: 'contacts/getCurrentUser',
    }),
    useInboxAvatarForBot() {
      return this.channelConfig.enabledFeatures.includes(
        'use_inbox_avatar_for_bot'
      );
    },
    hasAConnectedAgentBot() {
      return !!window.chatwootWebChannel.hasAConnectedAgentBot;
    },
    inboxAvatarUrl() {
      return window.chatwootWebChannel.avatarUrl;
    },
    channelConfig() {
      return window.chatwootWebChannel;
    },
    hasEmojiPickerEnabled() {
      return this.channelConfig.enabledFeatures.includes('emoji_picker');
    },
    hasAttachmentsEnabled() {
      return this.channelConfig.enabledFeatures.includes('attachments');
    },
    hasEndConversationEnabled() {
      return this.channelConfig.enabledFeatures.includes('end_conversation');
    },
    preChatFormEnabled() {
      return window.chatwootWebChannel.preChatFormEnabled;
    },
    preChatFormOptions() {
      let preChatMessage = '';
      const options = window.chatwootWebChannel.preChatFormOptions || {};
      preChatMessage = options.pre_chat_message;
      const { pre_chat_fields: preChatFields = [] } = options;
      return {
        preChatMessage,
        preChatFields,
      };
    },
    shouldShowPreChatForm() {
      const { preChatFields } = this.preChatFormOptions;
      // Check if at least one enabled field in pre-chat fields
      const hasEnabledFields =
        preChatFields.filter(field => field.enabled).length > 0;
      return this.preChatFormEnabled && hasEnabledFields;
    },
    /** Enabled pre-chat fields we still need to collect (after hiding known contact data). */
    remainingPreChatFieldsToCollect() {
      if (!this.shouldShowPreChatForm) return [];
      const { preChatFields } = this.preChatFormOptions;
      return filterPreChatFieldsByKnownContact(
        preChatFields,
        this.currentUser || {}
      ).filter(field => field.enabled);
    },
    /**
     * True when the visitor must complete the pre-chat screen before a new conversation
     * (inbox has pre-chat fields enabled and at least one is still empty for this contact).
     */
    shouldCollectPreChatFields() {
      return this.remainingPreChatFieldsToCollect.length > 0;
    },
  },
};
