# frozen_string_literal: true

require_relative 'async_callback'
require_relative 'config'
require_relative 'paths'
require_relative 'poller'
require_relative 'renderer'
require_relative 'reporter'
require_relative 'transform_pipeline'
require_relative 'user_data_assembler'
require_relative 'watcher'
require_relative 'webhook_receiver'

module TRMNLP
  class Context
    attr_reader :config, :paths, :reporter

    # The keywords after reporter let `trmnlp test` run the real pipeline with a test's inputs.
    # rubocop:disable-next Metrics/ParameterLists -- the composition root takes what it wires
    def initialize(root_dir, reporter: Reporter.new, cache_dir: nil, project_overrides: {}, outbound_request: nil,
                   transform_client: nil, source_data: nil)
      @paths = Paths.new(root_dir, cache_dir:)
      @config = Config.new(paths, project_overrides:)
      @reporter = reporter
      @outbound_request = outbound_request
      @transform_client = transform_client
      @source_data = source_data
    end

    # Context is the composition root: it wires and memoizes the runtime
    # object graph. Callers take the collaborator they need and talk to it
    # directly — Context does not forward methods on their behalf.
    def poller
      @poller ||= Poller.new(config:, paths:, oauth_session:, reporter:, async_callback:,
                             outbound_request: @outbound_request,
                             trmnl_variables: -> { user_data_assembler.polling_variables })
    end

    def async_callback = @async_callback ||= AsyncCallback.new(config:, paths:, reporter:)

    def oauth_session
      @oauth_session ||= begin
        provider = OAuth::Provider.new(config.plugin.settings)
        OAuth::Session.new(provider:,
                           token_store: OAuth::TokenStore.new(paths.oauth_tokens),
                           client: OAuth::Client.new(provider))
      end
    end

    def transform_pipeline
      @transform_pipeline ||= TransformPipeline.new(config:, paths:, reporter:, client: @transform_client)
    end

    def user_data_assembler
      @user_data_assembler ||= UserDataAssembler.new(config:, paths:, transform_pipeline:, oauth_session:,
                                                     source_data: @source_data)
    end

    def renderer = @renderer ||= Renderer.new(config:, paths:, user_data_assembler:)
    def watcher = @watcher ||= Watcher.new(config:, user_data_assembler:, transform_pipeline:, reporter:)

    def webhook_receiver
      @webhook_receiver ||= WebhookReceiver.new(paths:, transform_pipeline:, user_data_assembler:, reporter:)
    end

    def validate!
      raise NotAPlugin, "not a plugin directory (did not find #{paths.trmnlp_config})" unless paths.valid?
    end
  end
end
