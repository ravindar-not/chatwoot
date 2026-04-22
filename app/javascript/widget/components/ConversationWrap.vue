<script>
import ChatMessage from 'widget/components/ChatMessage.vue';
import AgentMessage from 'widget/components/AgentMessage.vue';
import AgentTypingBubble from 'widget/components/AgentTypingBubble.vue';
import DateSeparator from 'shared/components/DateSeparator.vue';
import Spinner from 'shared/components/Spinner.vue';
import { useDarkMode } from 'widget/composables/useDarkMode';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { mapActions, mapGetters } from 'vuex';

export default {
  name: 'ConversationWrap',
  components: {
    ChatMessage,
    AgentMessage,
    AgentTypingBubble,
    DateSeparator,
    Spinner,
  },
  props: {
    groupedMessages: {
      type: Array,
      default: () => [],
    },
  },
  setup() {
    const { darkMode } = useDarkMode();
    return { darkMode };
  },
  data() {
    return {
      previousScrollHeight: 0,
      previousConversationSize: 0,
    };
  },
  computed: {
    ...mapGetters({
      earliestMessage: 'conversation/getEarliestMessage',
      lastMessage: 'conversation/getLastMessage',
      allMessagesLoaded: 'conversation/getAllMessagesLoaded',
      isFetchingList: 'conversation/getIsFetchingList',
      conversationSize: 'conversation/getConversationSize',
      isAgentTyping: 'conversation/getIsAgentTyping',
      conversationAttributes: 'conversationAttributes/getConversationParams',
      fourAyStreamReply: 'conversation/getFourAyStreamReply',
    }),
    showFourAyStreamBubble() {
      const s = this.fourAyStreamReply;
      if (!s?.active || !s.content) {
        return false;
      }
      return String(s.conversationId) === String(this.conversationAttributes.id);
    },
    /** Same shape as persisted agent messages so +AgentMessage+ renders identical layout. */
    fourAyStreamPlaceholderMessage() {
      if (!this.showFourAyStreamBubble) return null;
      const s = this.fourAyStreamReply;
      const name =
        window.chatwootWebChannel?.websiteName ||
        this.$t('UNREAD_VIEW.BOT');
      return {
        id: `four-ay-stream-${s.streamId}`,
        content: s.content,
        message_type: MESSAGE_TYPE.OUTGOING,
        content_type: '',
        content_attributes: {},
        showAvatar: true,
        sender: {
          name,
          available_name: name,
          type: 'user',
          avatar_url: null,
        },
        attachments: [],
        created_at: new Date().toISOString(),
      };
    },
    colorSchemeClass() {
      return `${this.darkMode === 'dark' ? 'dark-scheme' : 'light-scheme'}`;
    },
    showStatusIndicator() {
      // While we are rendering streamed content, suppress the separate typing bubble
      // to avoid duplicate "loading" rows.
      if (this.fourAyStreamReply?.active) return false;
      const { status } = this.conversationAttributes;
      const isLastMessageIncoming =
        this.lastMessage.message_type === MESSAGE_TYPE.INCOMING;
      // Web widget conversations are usually `open` (not only `pending`) while waiting for a reply.
      const isWaitingForAgentReply =
        isLastMessageIncoming &&
        (status === 'pending' || status === 'open');
      return this.isAgentTyping || isWaitingForAgentReply;
    },
  },
  watch: {
    allMessagesLoaded() {
      this.previousScrollHeight = 0;
    },
    fourAyStreamReply: {
      deep: true,
      handler() {
        if (!this.showFourAyStreamBubble) return;
        // Measure after DOM updates; if the user scrolled up, stay put (ChatGPT-style).
        this.scrollStreamToBottomIfPinned();
      },
    },
  },
  mounted() {
    this.$el.addEventListener('scroll', this.handleScroll);
    this.scrollToBottom();
  },
  updated() {
    if (this.previousConversationSize !== this.conversationSize) {
      this.previousConversationSize = this.conversationSize;
      this.scrollToBottom();
    }
  },
  unmounted() {
    this.$el.removeEventListener('scroll', this.handleScroll);
  },
  methods: {
    ...mapActions('conversation', ['fetchOldConversations']),
    /**
     * Chat-style auto-follow: only true when the viewport is pinned to the newest content.
     * Must be called after layout reflects current content (e.g. inside $nextTick).
     */
    isPinnedToBottom(container, thresholdPx = 140) {
      if (!container) return true;
      const gap =
        container.scrollHeight - container.scrollTop - container.clientHeight;
      return gap <= thresholdPx;
    },
    scrollStreamToBottomIfPinned() {
      if (!this.showFourAyStreamBubble) return;
      this.$nextTick(() => {
        requestAnimationFrame(() => {
          const el = this.$el;
          if (!el || !this.isPinnedToBottom(el)) return;
          el.scrollTop = el.scrollHeight;
        });
      });
    },
    scrollToBottom() {
      const container = this.$el;
      container.scrollTop = container.scrollHeight - this.previousScrollHeight;
      this.previousScrollHeight = 0;
    },
    handleScroll() {
      if (
        this.isFetchingList ||
        this.allMessagesLoaded ||
        !this.conversationSize
      ) {
        return;
      }

      if (this.$el.scrollTop < 100) {
        this.fetchOldConversations({ before: this.earliestMessage.id });
        this.previousScrollHeight = this.$el.scrollHeight;
      }
    },
  },
};
</script>

<template>
  <div class="conversation--container" :class="colorSchemeClass">
    <div class="conversation-wrap" :class="{ 'is-typing': isAgentTyping }">
      <div v-if="isFetchingList" class="message--loader">
        <Spinner />
      </div>
      <div
        v-for="groupedMessage in groupedMessages"
        :key="groupedMessage.date"
        class="messages-wrap"
      >
        <DateSeparator :date="groupedMessage.date" />
        <ChatMessage
          v-for="message in groupedMessage.messages"
          :key="message.id"
          :message="message"
        />
      </div>
      <div v-if="fourAyStreamPlaceholderMessage" class="messages-wrap">
        <AgentMessage
          :id="`cwmsg-${fourAyStreamPlaceholderMessage.id}`"
          :message="fourAyStreamPlaceholderMessage"
        />
      </div>
      <AgentTypingBubble v-if="showStatusIndicator" />
    </div>
  </div>
</template>

<style scoped lang="scss">
.conversation--container {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow-y: auto;
  color-scheme: light dark;

  &.light-scheme {
    color-scheme: light;
  }

  &.dark-scheme {
    color-scheme: dark;
  }
}

.conversation-wrap {
  flex: 1;
  @apply px-2 pt-8 pb-2;
}

.message--loader {
  text-align: center;
}
</style>
