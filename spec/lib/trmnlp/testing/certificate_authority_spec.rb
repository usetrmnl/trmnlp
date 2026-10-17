# frozen_string_literal: true

require 'trmnlp/testing/certificate_authority'

RSpec.describe TRMNLP::Testing::CertificateAuthority do
  subject(:authority) { described_class.new }

  after { authority.remove }

  describe '#ssl_context_for' do
    # Python 3.13 verifies with X509_STRICT, which rejects a chain without key identifiers.
    it 'signs a leaf that passes strict verification' do
      store = OpenSSL::X509::Store.new.tap do |trusted|
        trusted.add_file(authority.pem_path)
        trusted.flags = OpenSSL::X509::V_FLAG_X509_STRICT
      end

      expect(store.verify(authority.ssl_context_for('api.test').cert)).to be(true), -> { store.error_string }
    end
  end
end
