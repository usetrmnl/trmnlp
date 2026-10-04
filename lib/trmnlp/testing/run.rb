# frozen_string_literal: true

require 'delegate'
require 'json'
require 'tmpdir'

require_relative '../context'
require_relative '../reporter'
require_relative '../transform_backend/subprocess'
require_relative '../transform_backend/which'
require_relative '../transform_client'
require_relative '../transform_state'
require_relative 'frozen_clock'
require_relative 'memory_sampler'
require_relative 'node_version'
require_relative 'mock_proxy'
require_relative 'mock_table'

module TRMNLP
  module Testing
    # One transform or render of a plugin, through trmnlp's own pipeline, in a cache directory of its own:
    # the test's custom fields, saved state and previous output go in, its mocks answer every request,
    # and every clock starts at its `now`.
    class Run
      Result = Data.define(:data, :html, :state, :requests, :log, :error, :duration_ms, :max_memory_mb)

      # The transform client, remembering how long its last run took.
      class TimedClient < SimpleDelegator
        attr_reader :duration_ms

        def execute(**) = super.tap { @duration_ms = it.duration_ms }
      end

      # rubocop:disable-next Metrics/ParameterLists -- one keyword per input a test can set
      def initialize(plugin:, authority:, now: nil, custom_fields: {}, variables: {}, state: nil,
                     previous_merge_variables: nil, data: nil, mocks: {}, transform: true)
        @plugin = plugin.to_s
        @authority = authority
        @now = now
        @inputs = { custom_fields:, variables:, state:, previous_merge_variables:, data:, transform: }
        @table = MockTable.new(mocks, on_advance_clock: method(:advance_clock))
        @clock_offset = 0
        @reporter = Reporter.new(quiet: true)
      end

      def transform(device: {})
        call { |context| { data: context.user_data_assembler.call(device:) } }
      end

      def render(view:, device: {}, screen_classes: nil, theme: nil)
        call do |context|
          html = context.renderer.render_full_page(view, device.merge(screen_classes:, theme:))
          { html:, data: context.renderer.last_data }
        end
      end

      private

      attr_reader :plugin, :authority, :now, :inputs, :table, :reporter

      def call
        Dir.mktmpdir('trmnlp-run-') do |cache_dir|
          @clock_file = File.join(cache_dir, 'clock')
          MockProxy.open(table:, authority:) do |proxy|
            context = build_context(cache_dir, proxy)
            parts = FrozenClock.around(now) do
              load_source_data(context)
              yield context
            end
            Result.new(data: nil, html: nil, **parts, **outcome(context))
          end
        end
      end

      def build_context(cache_dir, proxy)
        transform_client = inputs[:transform] ? transform_client(proxy) : nil
        context = Context.new(plugin, reporter:, cache_dir:, project_overrides:, outbound_request: table,
                                      transform_client:)
        seed(context.paths)
        context
      end

      def project_overrides
        overrides = { 'custom_fields' => stringify(inputs[:custom_fields]),
                      'variables' => stringify(inputs[:variables]) }
        inputs[:transform] ? overrides : overrides.merge('transform_runtime' => 'disabled')
      end

      def transform_client(proxy)
        environment = proxy.environment
        language = transform_language
        NodeVersion.check!(interpreter(language)) if language.to_s == 'node'
        if now && language
          environment = environment.merge(FrozenClock.environment(now, interpreter: interpreter(language),
                                                                       clock_file: @clock_file))
        end
        on_spawn = ->(pid) { @memory = MemorySampler.start(pid) }
        backend = TransformBackend::Subprocess.new(environment:, on_spawn:)
        @client = TimedClient.new(TransformClient.new(backend:))
      end

      def transform_language
        paths = Paths.new(plugin)
        _path, inferred = paths.transform_file
        Config.new(paths).plugin.serverless_language || inferred
      end

      def interpreter(language)
        commands = TransformBackend::Subprocess::INTERPRETERS.fetch(language.to_s, { cmds: [language.to_s] })[:cmds]
        TransformBackend::Which.locate(TransformBackend::Which.resolve(commands)).to_s
      end

      def seed(paths)
        write(paths.transform_state, inputs[:state]) if inputs[:state]
        write(paths.transform_output, inputs[:previous_merge_variables]) if inputs[:previous_merge_variables]
      end

      def load_source_data(context)
        if inputs[:data]
          write(context.paths.user_data, inputs[:data])
        elsif context.config.plugin.polling?
          context.poller.poll_data
        end
        time = now || Time.now
        File.utime(time, time, context.paths.user_data) if context.paths.user_data.exist?
      end

      # A mock's advance_clock: moves the transform's clock on from the test's now.
      def advance_clock(seconds)
        raise TestingError, 'advance_clock needs now: on the run' unless now

        @clock_offset += seconds
        FrozenClock.write(@clock_file, now + @clock_offset)
      end

      def outcome(context)
        table.finish
        { state: TransformState.new(paths: context.paths).read, requests: table.requests, log: reporter.messages,
          error: context.transform_pipeline.error, duration_ms: @client&.duration_ms, max_memory_mb: @memory&.peak_mb }
      end

      def stringify(value) = JSON.parse(JSON.generate(value || {}))

      def write(path, value)
        path.dirname.mkpath
        path.write(JSON.generate(value))
      end
    end
  end
end
