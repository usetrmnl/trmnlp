# frozen_string_literal: true

require_relative 'base'

module TRMNLP
  module Commands
    class Build < Base
      Options = Data.define(:dir, :quiet)

      def call
        context.validate!
        report_form_field_warnings
        context.poller.poll_data
        context.paths.create_build_dir

        Screen.all.each do |screen|
          output_path = context.paths.build_dir.join("#{screen.name}.html")
          reporter.info "Writing #{output_path}..."
          output_path.write(context.renderer.render_full_page(screen.name))
        end

        reporter.info 'Done!'
      end
    end
  end
end
