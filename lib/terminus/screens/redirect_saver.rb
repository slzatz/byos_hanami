# frozen_string_literal: true

require "dry/monads"

module Terminus
  module Screens
    # Saves remote URI as a redirect file.
    class RedirectSaver
      include Dry::Monads[:result]

      def call remote_uri, output_path
        redirect_path = output_path.sub_ext(".redirect")
        
        begin
          File.write(redirect_path, remote_uri)
          Success redirect_path.to_s
        rescue StandardError => error
          Failure error.message
        end
      end
    end
  end
end