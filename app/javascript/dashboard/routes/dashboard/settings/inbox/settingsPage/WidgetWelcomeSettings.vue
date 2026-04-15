<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const uiFlags = useMapGetter('inboxes/getUIFlags');

const mainHeading = ref('');
const secondHeading = ref('');
const suggestedQueries = ref([]);

const emptyQuery = () => ({ label: '', message: '' });

const setDefaults = () => {
  const cfg = props.inbox.widget_welcome_config;
  mainHeading.value = cfg?.main_heading || '';
  secondHeading.value = cfg?.second_heading || '';
  const queries = cfg?.suggested_queries;
  suggestedQueries.value =
    Array.isArray(queries) && queries.length
      ? queries.map(q => ({
          label: q.label || '',
          message: q.message || '',
        }))
      : [];
};

const addQuery = () => {
  suggestedQueries.value = [...suggestedQueries.value, emptyQuery()];
};

const removeQuery = index => {
  suggestedQueries.value = suggestedQueries.value.filter((_, i) => i !== index);
};

const save = async () => {
  try {
    const payload = {
      id: props.inbox.id,
      formData: false,
      widget_welcome_config: {
        main_heading: mainHeading.value,
        second_heading: secondHeading.value,
        suggested_queries: suggestedQueries.value
          .map(q => ({
            label: (q.label || '').trim(),
            message: (q.message || '').trim(),
          }))
          .filter(q => q.message.length > 0),
      },
    };
    await store.dispatch('inboxes/updateInbox', payload);
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE')
    );
  }
};

watch(() => props.inbox, setDefaults, { deep: true, immediate: true });
</script>

<template>
  <div class="mx-6 max-w-4xl">
    <p class="text-n-slate-11 text-sm mb-6">
      {{ $t('INBOX_MGMT.WIDGET_WELCOME.DESCRIPTION') }}
    </p>
    <form class="flex flex-col gap-2" @submit.prevent="save">
      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WIDGET_WELCOME.MAIN_HEADING.LABEL')"
        :help-text="$t('INBOX_MGMT.WIDGET_WELCOME.MAIN_HEADING.HELP')"
      >
        <Input
          v-model="mainHeading"
          :placeholder="$t('INBOX_MGMT.WIDGET_WELCOME.MAIN_HEADING.PLACEHOLDER')"
        />
      </SettingsFieldSection>
      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WIDGET_WELCOME.SECOND_HEADING.LABEL')"
        :help-text="$t('INBOX_MGMT.WIDGET_WELCOME.SECOND_HEADING.HELP')"
      >
        <Input
          v-model="secondHeading"
          :placeholder="$t('INBOX_MGMT.WIDGET_WELCOME.SECOND_HEADING.PLACEHOLDER')"
        />
      </SettingsFieldSection>
      <div class="w-full py-2 mb-2">
        <div
          class="grid grid-cols-1 lg:grid-cols-8 gap-1.5 lg:gap-4 items-start lg:items-center"
        >
          <div class="text-heading-3 text-n-slate-12 col-span-1 lg:col-span-2">
            {{ $t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.LABEL') }}
          </div>
          <div class="col-span-1 lg:col-span-6 flex flex-col gap-4">
            <p class="text-label-small text-n-slate-11">
              {{ $t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.HELP') }}
            </p>
            <div
              v-for="(row, index) in suggestedQueries"
              :key="index"
              class="flex flex-col sm:flex-row gap-2 sm:gap-3 sm:items-end"
            >
              <Input
                v-model="row.label"
                class="flex-1"
                :label="$t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.BUTTON_LABEL')"
                :placeholder="$t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.BUTTON_LABEL_PLACEHOLDER')"
              />
              <Input
                v-model="row.message"
                class="flex-1"
                :label="$t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.MESSAGE')"
                :placeholder="$t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.MESSAGE_PLACEHOLDER')"
              />
              <Button
                type="button"
                variant="faded"
                color="ruby"
                class="shrink-0"
                @click="removeQuery(index)"
              >
                {{ $t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.REMOVE') }}
              </Button>
            </div>
            <Button
              type="button"
              variant="faded"
              color="slate"
              class="self-start"
              @click="addQuery"
            >
              {{ $t('INBOX_MGMT.WIDGET_WELCOME.SUGGESTED_QUERIES.ADD') }}
            </Button>
          </div>
        </div>
      </div>
      <div class="flex justify-end pt-4">
        <Button
          type="submit"
          :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
          :is-loading="uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>
