<script>
import { useAlert } from 'dashboard/composables';
import inboxMixin from 'shared/mixins/inboxMixin';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import InboxesAPI from 'dashboard/api/inboxes';
import types from 'dashboard/store/mutation-types';

export default {
  components: {
    SettingsFieldSection,
    NextButton,
  },
  mixins: [inboxMixin],
  props: {
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      mailFrom: '',
      mailSubject: '',
      isSaving: false,
    };
  },
  watch: {
    inbox: {
      handler() {
        this.setFromInbox();
      },
      deep: true,
    },
  },
  mounted() {
    this.setFromInbox();
  },
  methods: {
    setFromInbox() {
      const ec = this.inbox.email_configuration || {};
      this.mailFrom = ec.mail_from || '';
      this.mailSubject = ec.mail_subject || '';
    },
    async save() {
      this.isSaving = true;
      try {
        await InboxesAPI.updateEmailConfiguration(this.inbox.id, {
          email_configuration: {
            mail_from: this.mailFrom || null,
            mail_subject: this.mailSubject || null,
          },
        });
        const inboxResponse = await InboxesAPI.show(this.inbox.id);
        this.$store.commit(`inboxes/${types.EDIT_INBOXES}`, inboxResponse.data);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(
          error?.message || this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE')
        );
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div class="space-y-6">
    <p class="text-body-para text-n-slate-11">
      {{ $t('INBOX_MGMT.EMAIL_CONFIGURATION.DESCRIPTION') }}
    </p>
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.EMAIL_CONFIGURATION.MAIL_FROM_LABEL')"
      :help-text="$t('INBOX_MGMT.EMAIL_CONFIGURATION.MAIL_FROM_HELP')"
    >
      <woot-input
        v-model="mailFrom"
        type="text"
        class="w-full [&>input]:!mb-0"
        :placeholder="$t('INBOX_MGMT.EMAIL_CONFIGURATION.MAIL_FROM_PLACEHOLDER')"
      />
    </SettingsFieldSection>
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.EMAIL_CONFIGURATION.MAIL_SUBJECT_LABEL')"
      :help-text="$t('INBOX_MGMT.EMAIL_CONFIGURATION.MAIL_SUBJECT_HELP')"
    >
      <woot-input
        v-model="mailSubject"
        type="text"
        class="w-full [&>input]:!mb-0"
        :placeholder="$t('INBOX_MGMT.EMAIL_CONFIGURATION.MAIL_SUBJECT_PLACEHOLDER')"
      />
    </SettingsFieldSection>
    <div class="flex justify-end">
      <NextButton
        :is-loading="isSaving"
        :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
        @click="save"
      />
    </div>
  </div>
</template>
