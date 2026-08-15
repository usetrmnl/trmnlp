# frozen_string_literal: true

Dir[File.join(__dir__, 'commands', '*.rb')].each { |file| require file }
