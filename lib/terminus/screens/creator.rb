# frozen_string_literal: true

require "dry/monads"

module Terminus
  module Screens
    # Saves Base64 encoded content as image.
    class Creator
      include Dry::Monads[:result]

      def initialize decoder: Decoder.new, html_saver: HTMLSaver.new, uri_saver: URISaver.new, redirect_saver: RedirectSaver.new
        @decoder = decoder
        @html_saver = html_saver
        @uri_saver = uri_saver
        @redirect_saver = redirect_saver
      end

      def call output_path, **parameters
        case parameters
          in content:, dimensions: then html_saver.call content, output_path, dimensions
          in content: then html_saver.call content, output_path
          in uri:, dimensions: then uri_saver.call uri, output_path, dimensions
          in data:, dimensions: then decoder.call data, output_path, dimensions
          in remote_uri: then redirect_saver.call remote_uri, output_path
          else Failure "Invalid parameters: #{parameters.inspect}."
        end
      end

      private

      attr_reader :decoder, :html_saver, :uri_saver, :redirect_saver
    end
  end
end
