import BaseActionCableConnector from '../../shared/helpers/BaseActionCableConnector';
import { playNewMessageNotificationInWidget } from 'widget/helpers/WidgetAudioNotificationHelper';
import { ON_AGENT_MESSAGE_RECEIVED } from '../constants/widgetBusEvents';
import { IFrameHelper } from 'widget/helpers/utils';
import { shouldTriggerMessageUpdateEvent } from './IframeEventHelper';
import { CHATWOOT_ON_MESSAGE } from '../constants/sdkEvents';
import { emitter } from '../../shared/helpers/mitt';

const isMessageInActiveConversation = (getters, message) => {
  const { conversation_id: conversationId } = message;
  const activeConversationId =
    getters['conversationAttributes/getConversationParams'].id;
  return activeConversationId && conversationId !== activeConversationId;
};

const WIDGET_PRESENCE_INTERVAL = 60000;

class ActionCableConnector extends BaseActionCableConnector {
  constructor(app, pubsubToken) {
    super(app, pubsubToken, '', WIDGET_PRESENCE_INTERVAL);
    this.events = {
      'message.created': this.onMessageCreated,
      'four_ay.reply_stream': this.onFourAyReplyStream,
      'message.updated': this.onMessageUpdated,
      'conversation.typing_on': this.onTypingOn,
      'conversation.typing_off': this.onTypingOff,
      'conversation.status_changed': this.onStatusChange,
      'conversation.created': this.onConversationCreated,
      'presence.update': this.onPresenceUpdate,
      'contact.merged': this.onContactMerge,
    };
  }

  onDisconnected = () => {
    this.setLastMessageId();
  };

  onReconnect = () => {
    this.syncLatestMessages();
  };

  setLastMessageId = () => {
    this.app.$store.dispatch('conversation/setLastMessageId');
  };

  syncLatestMessages = () => {
    this.app.$store.dispatch('conversation/syncLatestMessages');
  };

  onStatusChange = data => {
    if (data.status === 'resolved') {
      this.app.$store.dispatch('campaign/resetCampaign');
    }
    this.app.$store.dispatch('conversationAttributes/update', data);
  };

  onFourAyReplyStream = data => {
    const activeId =
      this.app.$store.getters['conversationAttributes/getConversationParams'].id;
    if (!activeId || String(data.conversation_id) !== String(activeId)) {
      return;
    }
    this.app.$store.commit('conversation/setFourAyStreamReply', {
      conversation_id: data.conversation_id,
      stream_id: data.stream_id,
      content: data.content,
    });
  };

  onMessageCreated = data => {
    if (isMessageInActiveConversation(this.app.$store.getters, data)) {
      return;
    }

    const attrs = data.content_attributes || {};
    const stream = this.app.$store.getters['conversation/getFourAyStreamReply'];
    if (
      stream?.active &&
      attrs.four_ay_stream_id != null &&
      String(attrs.four_ay_stream_id) === String(stream.streamId)
    ) {
      this.app.$store.commit('conversation/clearFourAyStreamReply');
    }

    this.app.$store
      .dispatch('conversation/addOrUpdateMessage', data)
      .then(() => emitter.emit(ON_AGENT_MESSAGE_RECEIVED));

    IFrameHelper.sendMessage({
      event: 'onEvent',
      eventIdentifier: CHATWOOT_ON_MESSAGE,
      data,
    });
    if (data.sender_type === 'User') {
      playNewMessageNotificationInWidget();
    }
  };

  onMessageUpdated = data => {
    if (isMessageInActiveConversation(this.app.$store.getters, data)) {
      return;
    }

    if (shouldTriggerMessageUpdateEvent(data)) {
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_MESSAGE,
        data,
      });
    }

    this.app.$store.dispatch('conversation/addOrUpdateMessage', data);
  };

  onConversationCreated = () => {
    this.app.$store.dispatch('conversationAttributes/getAttributes');
  };

  onPresenceUpdate = data => {
    this.app.$store.dispatch('agent/updatePresence', data.users);
  };

  // eslint-disable-next-line class-methods-use-this
  onContactMerge = data => {
    const { pubsub_token: pubsubToken } = data;
    ActionCableConnector.refreshConnector(pubsubToken);
  };

  onTypingOn = data => {
    const activeConversationId =
      this.app.$store.getters['conversationAttributes/getConversationParams']
        .id;
    const eventConversationId = data.conversation?.id;
    // Before getAttributes/sync, active id can be empty; do not treat as "other conv"
    // (otherwise first typing_on is dropped: e.g. 35 !== '').
    const hasSyncedActiveId =
      activeConversationId !== null &&
      activeConversationId !== undefined &&
      activeConversationId !== '';
    const isTypingForDifferentConversation =
      hasSyncedActiveId &&
      eventConversationId != null &&
      String(eventConversationId) !== String(activeConversationId);

    if (isTypingForDifferentConversation || data.is_private) {
      return;
    }
    this.clearTimer();
    this.app.$store.dispatch('conversation/toggleAgentTyping', {
      status: 'on',
    });
    this.initTimer();
  };

  onTypingOff = () => {
    this.clearTimer();
    this.app.$store.dispatch('conversation/toggleAgentTyping', {
      status: 'off',
    });
  };

  clearTimer = () => {
    if (this.CancelTyping) {
      clearTimeout(this.CancelTyping);
      this.CancelTyping = null;
    }
  };

  initTimer = () => {
    // Turn off typing automatically after 30 seconds
    this.CancelTyping = setTimeout(() => {
      this.onTypingOff();
    }, 30000);
  };
}

export default ActionCableConnector;
