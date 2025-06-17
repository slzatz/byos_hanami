# frozen_string_literal: true

require "dry/monads"
require "initable"
require "petail"
require "trmnl/api"

module Terminus
  module Actions
    module API
      module Display
        # The show action.
        class Show < Terminus::Action
          include Deps[
            :settings,
            image_fetcher: "aspects.screens.rotator",
            firmware_fetcher: "aspects.firmware.fetcher",
            synchronizer: "aspects.synchronizers.device",
            repository: "repositories.device"
          ]

          include Initable[problem: Petail, model: TRMNL::API::Models::Display]
          include Dry::Monads[:result]

          using Refines::Actions::Response

          format :json

          def handle request, response
            environment = request.env

            case synchronizer.call environment
              in Success(synced_device)
                # Get the latest device state to ensure we have current last_displayed_image_mtime
                device = repository.find(synced_device.id)
                image = fetch_image(request.params, environment, device)
                current_image_mtime = get_image_mtime(device, image)
                special_function = determine_special_function(device, image)
                record = build_record(image, device, special_function)
                
                # Update the device's last displayed time after determining special_function
                if current_image_mtime
                  repository.update(device.id, last_displayed_image_mtime: current_image_mtime)
                end
                
                response.with body: record.to_json, status: 200
              else not_found response
            end
          end

          private

          def fetch_image parameters, environment, device
            encryption = :base_64 if (environment["HTTP_BASE64"] || parameters[:base_64]) == "true"

            image_fetcher.call device, encryption:
          end

          def build_record image, device, special_function
            model[
              firmware_url: fetch_firmware_uri(device),
              special_function: special_function,
              **image.slice(:image_url, :filename),
              **device.as_api_display
            ]
          end

          # :reek:FeatureEnvy
          def fetch_firmware_uri device
            firmware_fetcher.call.first.then do |firmware|
              firmware.uri if firmware && device.firmware_version != firmware.version
            end
          end

          def determine_special_function device, image
            return "sleep" unless device.last_displayed_image_mtime
            
            current_image_mtime = get_image_mtime(device, image)
            return "sleep" unless current_image_mtime
            
            # Round both times to microseconds to handle database precision differences
            current_rounded = Time.at(current_image_mtime.to_f.round(6))
            stored_rounded = Time.at(device.last_displayed_image_mtime.to_f.round(6))
            
            # Compare timestamps with a small tolerance to handle precision differences
            time_diff = (current_rounded.to_f - stored_rounded.to_f).abs
            if time_diff > 0.001  # More than 1ms difference means it's a new/updated image
              "sleep"
            else
              "none"
            end
          end

          def get_image_mtime device, image
            return nil if image[:filename] == "setup"
            
            image_path = settings.screens_root.join(device.slug).join(image[:filename])
            return nil unless image_path.exist?
            
            image_path.mtime
          end


          def not_found response
            body = problem[
              type: "/problem_details#device_id",
              status: __method__,
              detail: "Invalid device ID.",
              instance: "/api/display"
            ]

            response.with body: body.to_json, format: :problem_details, status: 404
          end
        end
      end
    end
  end
end
