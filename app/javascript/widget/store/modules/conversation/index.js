import { getters } from './getters';
import { actions } from './actions';
import { mutations } from './mutations';

const state = {
  conversations: {},
  meta: {
    userLastSeenAt: undefined,
  },
  uiFlags: {
    allMessagesLoaded: false,
    isFetchingList: false,
    isAgentTyping: false,
    isCreating: false,
    /** True after user text is sent until an agent OUTGOING message is stored (see getComposerReplyPipelineBusy). */
    awaitingAgentReply: false,
  },
  lastMessageId: null,
  /** Ephemeral FourAY streaming reply (ActionCable +four_ay.reply_stream+). */
  fourAyStreamReply: {
    active: false,
    conversationId: null,
    streamId: null,
    content: '',
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
