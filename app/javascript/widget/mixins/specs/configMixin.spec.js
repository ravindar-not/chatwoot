import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import configMixin from '../configMixin';
import { reactive } from 'vue';

const createContactsStore = currentUser =>
  createStore({
    modules: {
      contacts: {
        namespaced: true,
        state: () => ({ currentUser }),
        getters: {
          getCurrentUser: state => state.currentUser,
        },
      },
    },
  });

const preChatFields = [
  {
    label: 'Email Id',
    name: 'emailAddress',
    type: 'email',
    field_type: 'standard',
    required: false,
    enabled: false,
  },
  {
    label: 'Full name',
    name: 'fullName',
    type: 'text',
    field_type: 'standard',
    required: true,
    enabled: true,
  },
];

global.chatwootWebChannel = {
  avatarUrl: 'https://test.url',
  hasAConnectedAgentBot: 'AgentBot',
  enabledFeatures: [
    'emoji_picker',
    'attachments',
    'end_conversation',
    'use_inbox_avatar_for_bot',
  ],
  preChatFormOptions: { pre_chat_fields: preChatFields, pre_chat_message: '' },
  preChatFormEnabled: true,
};

describe('configMixin', () => {
  test('returns config', () => {
    const store = createContactsStore({});
    const wrapper = shallowMount({
      mixins: [configMixin],
      data() {
        return {
          channelConfig: reactive(global.chatwootWebChannel),
        };
      },
      template: '<div />', // Render a simple div as the template
      global: {
        plugins: [store],
      },
    });

    expect(wrapper.vm.hasEmojiPickerEnabled).toBe(true);
    expect(wrapper.vm.hasEndConversationEnabled).toBe(true);
    expect(wrapper.vm.hasAttachmentsEnabled).toBe(true);
    expect(wrapper.vm.hasAConnectedAgentBot).toBe(true);
    expect(wrapper.vm.useInboxAvatarForBot).toBe(true);
    expect(wrapper.vm.inboxAvatarUrl).toBe('https://test.url');

    expect(wrapper.vm.channelConfig).toEqual({
      avatarUrl: 'https://test.url',
      hasAConnectedAgentBot: 'AgentBot',
      enabledFeatures: [
        'emoji_picker',
        'attachments',
        'end_conversation',
        'use_inbox_avatar_for_bot',
      ],
      preChatFormOptions: {
        pre_chat_message: '',
        pre_chat_fields: preChatFields,
      },
      preChatFormEnabled: true,
    });
    expect(wrapper.vm.preChatFormOptions).toEqual({
      preChatMessage: '',
      preChatFields: preChatFields,
    });
    expect(wrapper.vm.preChatFormEnabled).toBe(true);
    expect(wrapper.vm.shouldShowPreChatForm).toBe(true);
    expect(wrapper.vm.shouldCollectPreChatFields).toBe(true);
  });

  test('shouldCollectPreChatFields is false when contact already has identity fields', () => {
    const store = createContactsStore({
      has_email: true,
      has_phone_number: true,
      has_name: true,
    });
    const wrapper = shallowMount({
      mixins: [configMixin],
      template: '<div />',
      global: {
        plugins: [store],
      },
    });

    expect(wrapper.vm.shouldShowPreChatForm).toBe(true);
    expect(wrapper.vm.remainingPreChatFieldsToCollect).toEqual([]);
    expect(wrapper.vm.shouldCollectPreChatFields).toBe(false);
  });
});
