# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::FourAy::ResponseParser do
  describe '.extract_reply_from_sse' do
    it 'returns the last answer from SSE data events' do
      body = <<~SSE
        data: {"type":"run_meta","run_id":"abc","agent_id":360}

        data: {"status":"SUCCESS","answer":"Hello from stream","citations":[],"confidence":"HIGH","notes":""}

      SSE

      expect(described_class.extract_reply_from_sse(body)).to eq('Hello from stream')
    end
  end

  describe '.extract_reply_unified' do
    it 'uses SSE parser when body looks like SSE' do
      body = "data: {\"answer\":\"Hi\"}\n\n"
      expect(described_class.extract_reply_unified(body)).to eq('Hi')
    end

    it 'returns nil for SSE-looking buffer before any answer text (no raw dump)' do
      body = <<~SSE
        data: {"type":"run_meta","run_id":"a","agent_id":360}

        : keepalive

      SSE

      expect(described_class.extract_reply_unified(body)).to be_nil
    end

    it 'parses FourAY fragmented data: token stream (answer split across many data: lines)' do
      body = <<~FRAG
        data: {"type":"run_meta","run_id":"x","agent_id":360}

        : keepalive

        data: {
        data: "
        data: status
        data: ":
        data: "
        data: SUCCESS
        data: ",
        data: "
        data: answer
        data: ":
        data: "
        data: Hello
        data:  —
        data:  world
        data: "
      FRAG

      expect(described_class.extract_reply_unified(body)).to eq('Hello — world')
    end

    it 'keeps spaces between words when upstream uses data:  word lines' do
      body = <<~FRAG
        data: {"type":"run_meta"}

        data: {
        data: "
        data: answer
        data: ":
        data: "
        data: Hi
        data:  —
        data:  there
        data: "
      FRAG

      expect(described_class.extract_reply_unified(body)).to eq('Hi — there')
    end

    it 'uses JSON parser for plain JSON' do
      expect(described_class.extract_reply_unified({ 'answer' => 'Plain' })).to eq('Plain')
    end
  end
end
