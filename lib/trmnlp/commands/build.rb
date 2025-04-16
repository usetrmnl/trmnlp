require_relative 'base'

module TRMNLP
  module Commands
    class Build < Base
      def call
        context.validate!
        context.poll_data
        context.paths.create_build_dir

        VIEWS.each do |view|
          output_path = context.paths.build_dir.join("#{view}.html")
          output "Writing #{output_path}..."
          output_path.write(context.render_full_page(view))
        end
  
        output "Done!"
      end
    end
  end
end