<script>
import ArticleContainer from '../components/pageComponents/Home/Article/ArticleContainer.vue';
import ChatFooter from '../components/ChatFooter.vue';

export default {
  name: 'Home',
  components: {
    ArticleContainer,
    ChatFooter,
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
    <ChatFooter class="px-5" />
  </div>
</template>
