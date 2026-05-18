# frozen_string_literal: true

module TRMNLP
  class Error < StandardError; end

  class NotLoggedIn         < Error; end
  class NotAPlugin          < Error; end
  class DirectoryExists     < Error; end
  class Aborted             < Error; end
  class PluginIdRequired    < Error; end
  class InvalidApiKey       < Error; end
  class AuthenticationFailed < Error; end
  class InvalidConfig       < Error; end
  class RenderError         < Error; end
end
