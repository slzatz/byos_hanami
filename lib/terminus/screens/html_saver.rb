# frozen_string_literal: true

require "inspectable"

module Terminus
  module Screens
    # Creates device image.
    class HTMLSaver
      include Dependencies[:sanitizer]
      include Inspectable[sanitizer: :class]

      def initialize(screensaver: Screensaver.new, greyscaler: Greyscaler.new, **)
        super(**)
        @screensaver = screensaver
        @greyscaler = greyscaler
      end

      def call content, output_path, dimensions = nil
        Tempfile.create %w[creator- .jpg] do |file|
          path = file.path

          if dimensions
            viewport = parse_dimensions(dimensions)
            screensaver.call sanitizer.call(content), path, viewport: viewport
          else
            screensaver.call sanitizer.call(content), path
          end
          greyscaler.call path, output_path
        end
      end

      private

      attr_reader :screensaver, :greyscaler

      def parse_dimensions(dimensions)
        width, height = dimensions.split('x').map(&:to_i)
        {width: width, height: height, scale_factor: 1}
      end
    end
  end
end
