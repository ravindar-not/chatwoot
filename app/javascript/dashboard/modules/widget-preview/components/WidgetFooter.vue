<script setup>
import { ref } from 'vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

defineProps({
  config: {
    type: Object,
    default: () => ({}),
  },
});

const { formatMessage } = useMessageFormatter();

const isInputFocused = ref(false);
</script>

<template>
  <div class="relative flex flex-col w-full px-4">
    <div
      v-if="config.isDefaultScreen"
      class="p-4 rounded-md shadow-sm bg-n-background dark:bg-n-solid-2"
    >
      <div class="flex items-center justify-between">
        <div>
          <div
            v-if="config.welcomeTagline"
            class="text-xs text-n-slate-11 pr-2"
            v-dompurify-html="formatMessage(config.welcomeTagline)"
          />
        </div>
      </div>
      <button
        v-if="config.isDefaultScreen"
        class="inline-flex items-center justify-between px-2 py-1 mt-1 -ml-2 font-medium leading-6 bg-transparent rounded-md text-n-slate-12 dark:bg-transparent"
        :style="{ color: config.color }"
      >
        <span class="pr-2 text-xs">
          {{
            $t(
              'INBOX_MGMT.WIDGET_BUILDER.FOOTER.START_CONVERSATION_BUTTON_TEXT'
            )
          }}
        </span>
        <FluentIcon icon="arrow-right" size="14" />
      </button>
    </div>
    <div
      v-else
      class="flex items-center h-10 bg-white rounded-md dark:!bg-n-slate-3"
      :class="{ 'ring-2 ring-n-brand dark:ring-n-brand': isInputFocused }"
    >
      <ResizableTextArea
        id="chat-input"
        :rows="1"
        :placeholder="
          $t('INBOX_MGMT.WIDGET_BUILDER.FOOTER.CHAT_INPUT_PLACEHOLDER')
        "
        class="flex-grow !bg-white border-0 outline-none !outline-0 border-none h-8 text-sm dark:!bg-n-slate-3 pb-0 !pt-1.5 resize-none px-3 !mb-0 focus:outline-none rounded-md"
        @focus="isInputFocused = true"
        @blur="isInputFocused = false"
      />
      <div class="flex items-center gap-2 px-2">
        <FluentIcon icon="emoji" />
        <FluentIcon class="icon-send" icon="send" />
      </div>
    </div>
  </div>
</template>
