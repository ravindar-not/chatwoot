<script>
import { mapGetters } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import ArticleContainer from '../components/pageComponents/Home/Article/ArticleContainer.vue';
import ChatFooter from '../components/ChatFooter.vue';
import CustomButton from 'shared/components/Button.vue';
import configMixin from 'widget/mixins/configMixin';

export default {
  name: 'Home',
  components: {
    ArticleContainer,
    ChatFooter,
    CustomButton,
  },
  mixins: [configMixin],
  computed: {
    ...mapGetters({
      conversationSize: 'conversation/getConversationSize',
      widgetColor: 'appConfig/getWidgetColor',
    }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
  },
  methods: {
    goToPreChat() {
      this.$router.replace({ name: 'prechat-form' });
    },
  },
};
</script>

<template>
  <div
    class="z-50 flex min-h-0 flex-1 flex-col bg-n-slate-2 dark:bg-n-solid-1 rounded-b-lg pb-[max(1rem,env(safe-area-inset-bottom,0px))]"
  >
    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-auto p-4">
      <ArticleContainer />
    </div>
    <div
      v-if="shouldShowPreChatForm && conversationSize === 0"
      class="px-5 pt-1"
    >
      <CustomButton
        class="font-medium"
        block
        :bg-color="widgetColor"
        :text-color="textColor"
        @click="goToPreChat"
      >
        {{ $t('START_CONVERSATION') }}
      </CustomButton>
    </div>
    <ChatFooter v-else class="px-5" />
  </div>
</template>
