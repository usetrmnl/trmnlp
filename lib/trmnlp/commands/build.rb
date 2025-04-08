require_relative 'base'

module TRMNLP
  module Commands
    class Build < Base
      def call
        context = Context.new(options.dir)
        context.poll_data

        VIEWS.each do |view|
          output_path = context.paths.build_dir.join("#{view}.html")
          puts "Writing #{output_path}..."
          output_path.write(context.render_full_page(view))
        end
  
        puts "Done!"
      end
    end
  end
end