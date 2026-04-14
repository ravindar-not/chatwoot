<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import HeaderActions from './HeaderActions.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

const props = defineProps({
  avatarUrl: { type: String, default: '' },
  title: { type: String, default: '' },
  showPopoutButton: { type: Boolean, default: false },
  showBackButton: { type: Boolean, default: false },
  /** Welcome tagline shown under the inbox name (no online / reply-time UI). */
  staticSubtitle: { type: String, default: '' },
});

const router = useRouter();
const { formatMessage } = useMessageFormatter();

const formattedStaticSubtitle = computed(() =>
  props.staticSubtitle ? formatMessage(props.staticSubtitle) : ''
);

const onBackButtonClick = () => {
  router.replace({ name: 'home' });
};
</script>

<template>
  <header class="flex justify-between w-full p-5 bg-n-background gap-2">
    <div class="flex items-center">
      <button
        v-if="showBackButton"
        class="px-2 ltr:-ml-3 rtl:-mr-3"
        @click="onBackButtonClick"
      >
        <FluentIcon icon="chevron-left" size="24" class="text-n-slate-12" />
      </button>
      <img
        v-if="avatarUrl"
        class="w-8 h-8 ltr:mr-3 rtl:ml-3 rounded-full"
        :src="avatarUrl"
        alt="avatar"
      />
      <div class="flex flex-col gap-1">
        <div
          class="flex items-center text-base font-medium leading-4 text-n-slate-12"
        >
          <span v-dompurify-html="title" class="ltr:mr-1 rtl:ml-1" />
        </div>
        <p
          v-if="formattedStaticSubtitle"
          v-dompurify-html="formattedStaticSubtitle"
          class="text-xs leading-3 text-n-slate-11 [&_a]:underline"
        />
      </div>
    </div>
    <HeaderActions :show-popout-button="showPopoutButton" />
  </header>
</template>
