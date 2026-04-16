<script>
import { mapActions, mapGetters } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import CustomButton from 'shared/components/Button.vue';
import FooterReplyTo from 'widget/components/FooterReplyTo.vue';
import ChatInputWrap from 'widget/components/ChatInputWrap.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { sendEmailTranscript } from 'widget/api/conversation';
import { useRouter } from 'vue-router';
import { IFrameHelper } from '../helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from '../constants/sdkEvents';
import { emitter } from 'shared/helpers/mitt';

export default {
  components: {
    ChatInputWrap,
    CustomButton,
    FooterReplyTo,
  },
  setup() {
    const router = useRouter();
    return { router };
  },
  data() {
    return {
      inReplyTo: null,
    };
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      widgetColor: 'appConfig/getWidgetColor',
      conversationSize: 'conversation/getConversationSize',
      currentUser: 'contacts/getCurrentUser',
      isWidgetStyleFlat: 'appConfig/isWidgetStyleFlat',
    }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    hideReplyBox() {
      // Conversation screen always uses the composer (new messages use a new server-side thread when needed).
      if (this.$route.name === 'messages') {
        return false;
      }
      const { allowMessagesAfterResolved } = window.chatwootWebChannel;
      const { status } = this.conversationAttributes;
      const resolved = status === 'resolved';
      // Home is the "start fresh" screen after a conversation ends: always show the composer there.
      if (this.$route.name === 'home' && resolved) {
        return false;
      }
      return !allowMessagesAfterResolved && resolved;
    },
    showEmailTranscriptButton() {
      return this.hasEmail;
    },
    hasEmail() {
      return this.currentUser && this.currentUser.has_email;
    },
    hasReplyTo() {
      return (
        this.inReplyTo && (this.inReplyTo.content || this.inReplyTo.attachments)
      );
    },
    suggestedStarterQueries() {
      const list = window.chatwootWebChannel?.suggestedQueries;
      return Array.isArray(list) ? list : [];
    },
    showSuggestedStarters() {
      return (
        !this.hideReplyBox &&
        this.conversationSize === 0 &&
        this.suggestedStarterQueries.length > 0
      );
    },
    /** Suggested chips above the composer on home; below on messages. */
    chipsAboveInput() {
      return this.$route.name === 'home';
    },
    /** Suggested chips panel: full width, two columns. */
    suggestedChipsPanelClass() {
      return [
        'grid max-w-none grid-cols-2 gap-2.5',
        '-mx-5 w-[calc(100%+2.5rem)]',
        'border border-n-weak/90',
        'bg-white dark:bg-n-solid-2',
        'px-4 py-3.5',
        'shadow-[0_2px_12px_rgba(15,23,42,0.07)] dark:shadow-[0_2px_12px_rgba(0,0,0,0.35)]',
        'ring-1 ring-n-slate-4/15 dark:ring-n-slate-9/40',
      ].join(' ');
    },
    homeChipsContainerStyle() {
      if (!this.widgetColor) return {};
      return {
        borderTopWidth: '3px',
        borderTopColor: this.widgetColor,
        borderTopStyle: 'solid',
      };
    },
    /** Grid cell: label + optional message preview. */
    suggestedChipButtonClass() {
      return [
        'flex min-h-[4.25rem] w-full min-w-0 flex-col justify-center gap-1 rounded-xl px-3 py-2.5 text-left',
        'bg-n-alpha-2/90 dark:bg-n-alpha-2',
        'border border-n-weak dark:border-n-strong',
        'shadow-sm',
        'transition-all duration-150 ease-out',
        'hover:border-n-slate-6 hover:bg-n-alpha-3 hover:shadow dark:hover:border-n-slate-7',
        'active:scale-[0.99]',
        'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand',
      ].join(' ');
    },
  },
  mounted() {
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.toggleReplyTo);
  },
  methods: {
    ...mapActions('conversation', ['sendMessage', 'sendAttachment']),
    async handleSendMessage(content) {
      const fromHome = this.$route.name === 'home';
      await this.sendMessage({
        content,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      // reset replyTo message after sending
      this.inReplyTo = null;
      if (fromHome) {
        await this.router.replace({ name: 'messages' });
      }
    },
    async handleSendAttachment(attachment) {
      const fromHome = this.$route.name === 'home';
      await this.sendAttachment({
        attachment,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      this.inReplyTo = null;
      if (fromHome) {
        await this.router.replace({ name: 'messages' });
      }
    },
    selectSuggestedQuery(entry) {
      const message = String(entry?.message || '').trim();
      const label = String(entry?.label || '').trim();
      const text = message || label;
      if (!text) return;
      this.handleSendMessage(text);
    },
    suggestedQueryPrimaryText(entry) {
      if (!entry) return '';
      const label = String(entry.label || '').trim();
      const message = String(entry.message || '').trim();
      return label || message;
    },
    suggestedQuerySecondaryText(entry) {
      if (!entry) return '';
      const label = String(entry.label || '').trim();
      const message = String(entry.message || '').trim();
      if (!label || !message || label === message) return '';
      return message;
    },
    startNewConversation() {
      this.router.replace({ name: 'prechat-form' });
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
        data: { hasConversation: true },
      });
    },
    toggleReplyTo(message) {
      this.inReplyTo = message;
    },
    async sendTranscript() {
      if (this.hasEmail) {
        try {
          await sendEmailTranscript();
          emitter.emit(BUS_EVENTS.SHOW_ALERT, {
            message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_SUCCESS'),
            type: 'success',
          });
        } catch (error) {
          emitter.$emit(BUS_EVENTS.SHOW_ALERT, {
            message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'),
          });
        }
      }
    },
  },
};
</script>

<template>
  <footer
    v-if="!hideReplyBox"
    class="relative z-50 flex flex-col gap-3"
    :class="{
      'rounded-lg': !isWidgetStyleFlat,
      'pt-2.5 shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.05)] dark:shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.15)] rounded-t-none':
        hasReplyTo,
    }"
  >
    <FooterReplyTo
      v-if="hasReplyTo"
      :in-reply-to="inReplyTo"
      @dismiss="inReplyTo = null"
    />
    <div
      v-if="showSuggestedStarters && chipsAboveInput"
      :class="[
        suggestedChipsPanelClass,
        {
          'rounded-t-lg rounded-b-2xl': !isWidgetStyleFlat && !hasReplyTo,
          'rounded-2xl': isWidgetStyleFlat || hasReplyTo,
        },
      ]"
      :style="homeChipsContainerStyle"
    >
      <button
        v-for="(entry, index) in suggestedStarterQueries"
        :key="`above-${index}`"
        type="button"
        :class="suggestedChipButtonClass"
        @click="selectSuggestedQuery(entry)"
      >
        <span
          class="line-clamp-2 text-sm font-semibold leading-snug text-n-slate-12 dark:text-n-slate-11"
        >
          {{ suggestedQueryPrimaryText(entry) }}
        </span>
        <span
          v-if="suggestedQuerySecondaryText(entry)"
          class="line-clamp-2 text-xs font-normal leading-snug text-n-slate-10 dark:text-n-slate-11"
        >
          {{ suggestedQuerySecondaryText(entry) }}
        </span>
      </button>
    </div>
    <ChatInputWrap
      class="shadow-sm"
      :on-send-message="handleSendMessage"
      :on-send-attachment="handleSendAttachment"
    />
    <div
      v-if="showSuggestedStarters && !chipsAboveInput"
      :class="[suggestedChipsPanelClass, 'rounded-xl']"
    >
      <button
        v-for="(entry, index) in suggestedStarterQueries"
        :key="`below-${index}`"
        type="button"
        :class="suggestedChipButtonClass"
        @click="selectSuggestedQuery(entry)"
      >
        <span
          class="line-clamp-2 text-sm font-semibold leading-snug text-n-slate-12 dark:text-n-slate-11"
        >
          {{ suggestedQueryPrimaryText(entry) }}
        </span>
        <span
          v-if="suggestedQuerySecondaryText(entry)"
          class="line-clamp-2 text-xs font-normal leading-snug text-n-slate-10 dark:text-n-slate-11"
        >
          {{ suggestedQuerySecondaryText(entry) }}
        </span>
      </button>
    </div>
  </footer>
  <div v-else>
    <CustomButton
      class="font-medium"
      block
      :bg-color="widgetColor"
      :text-color="textColor"
      @click="startNewConversation"
    >
      {{ $t('START_NEW_CONVERSATION') }}
    </CustomButton>
    <CustomButton
      v-if="showEmailTranscriptButton"
      type="clear"
      class="font-normal"
      @click="sendTranscript"
    >
      {{ $t('EMAIL_TRANSCRIPT.BUTTON_TEXT') }}
    </CustomButton>
  </div>
</template>
