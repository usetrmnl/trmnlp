# frozen_string_literal: true

require 'fileutils'
require 'openssl'
require 'tmpdir'

module TRMNLP
  module Testing
    # A throwaway authority the transform process is told to trust, so MockProxy can answer HTTPS.
    # Lives for one server process; nothing is written outside its temp directory.
    class CertificateAuthority
      # Wide enough for any time a test freezes the clock at.
      VALID_FROM = Time.utc(2000, 1, 1)
      VALID_UNTIL = Time.utc(2099, 12, 31)

      attr_reader :pem_path, :bundle_path, :php_ini_dir

      def initialize
        @key = OpenSSL::PKey::RSA.new(2048)
        @certificate = sign(subject: 'trmnlp test CA', public_key: @key.public_key, authority: true)
        @leaves = {}
        @lock = Mutex.new
        write_files(Dir.mktmpdir('trmnlp-ca-'))
      end

      # The variables that make Node, Python, Ruby and PHP trust this authority.
      def environment
        { 'NODE_EXTRA_CA_CERTS' => pem_path, 'SSL_CERT_FILE' => bundle_path, 'REQUESTS_CA_BUNDLE' => bundle_path,
          'CURL_CA_BUNDLE' => bundle_path, 'PHP_INI_SCAN_DIR' => ":#{php_ini_dir}" }
      end

      def remove = FileUtils.remove_entry(File.dirname(pem_path))

      def ssl_context_for(host)
        @lock.synchronize do
          @leaves[host] ||= OpenSSL::SSL::SSLContext.new.tap do |context|
            context.key = @key
            context.cert = sign(subject: host, public_key: @key.public_key, authority: false, host:)
          end
        end
      end

      private

      def sign(subject:, public_key:, authority:, host: nil)
        certificate = OpenSSL::X509::Certificate.new
        certificate.version = 2
        certificate.serial = OpenSSL::BN.rand(64)
        certificate.subject = OpenSSL::X509::Name.parse("/CN=#{subject}")
        certificate.issuer = authority ? certificate.subject : @certificate.subject
        certificate.public_key = public_key
        certificate.not_before = VALID_FROM
        certificate.not_after = VALID_UNTIL
        add_extensions(certificate, authority, host)
        certificate.sign(@key, OpenSSL::Digest.new('SHA256'))
      end

      def add_extensions(certificate, authority, host)
        factory = OpenSSL::X509::ExtensionFactory.new(authority ? certificate : @certificate, certificate)
        if authority
          certificate.add_extension(factory.create_extension('basicConstraints', 'CA:TRUE', true))
          certificate.add_extension(factory.create_extension('keyUsage', 'keyCertSign,cRLSign', true))
        else
          name = host.match?(/\A[\d.]+\z/) ? "IP:#{host}" : "DNS:#{host}"
          certificate.add_extension(factory.create_extension('subjectAltName', name))
          certificate.add_extension(factory.create_extension('extendedKeyUsage', 'serverAuth'))
        end
      end

      def write_files(dir)
        @pem_path = File.join(dir, 'ca.pem')
        @bundle_path = File.join(dir, 'bundle.pem')
        @php_ini_dir = File.join(dir, 'php')
        File.write(pem_path, @certificate.to_pem)
        system_file = OpenSSL::X509::DEFAULT_CERT_FILE
        system_bundle = File.exist?(system_file) ? File.read(system_file) : ''
        File.write(bundle_path, system_bundle + @certificate.to_pem)
        Dir.mkdir(php_ini_dir)
        php_settings = "curl.cainfo=#{bundle_path}\nopenssl.cafile=#{bundle_path}\n"
        File.write(File.join(php_ini_dir, 'trmnlp-ca.ini'), php_settings)
      end
    end
  end
end
