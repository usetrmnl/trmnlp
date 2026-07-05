# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::OAuth::Pkce do
  describe '.challenge' do
    # RFC 7636 Appendix B test vector.
    it 'is the padless base64url S256 digest of the verifier' do
      verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'
      expect(described_class.challenge(verifier)).to eq('E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM')
    end
  end

  describe '.verifier' do
    it 'generates a url-safe string' do
      expect(described_class.verifier).to match(/\A[A-Za-z0-9\-_]+\z/)
    end
  end
end
