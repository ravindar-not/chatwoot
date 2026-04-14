<script>
import ArticleContainer from '../components/pageComponents/Home/Article/ArticleContainer.vue';

export default {
  name: 'Home',
  components: {
    ArticleContainer,
  },
};
</script>

<template>
  <div class="z-50 flex flex-col justify-end flex-1 w-full p-4 gap-4">
    <ArticleContainer />
  </div>
</template>
