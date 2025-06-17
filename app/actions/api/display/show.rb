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
                current_image_size = get_image_size(device, image)
                
                # Determine special_function BEFORE updating size (uses previous call's size)
                special_function = determine_special_function(device, image)
                record = build_record(image, device, special_function)
                
                # Update the device's file size for the NEXT API call
                if current_image_size
                  puts "DEBUG: About to update device #{device.id} for next call"
                  puts "DEBUG: current_image_size = #{current_image_size.inspect} (#{current_image_size.class})"
                  
                  # Store file size as an integer in the timestamp column (repurposing the column)
                  attributes = {last_displayed_image_mtime: current_image_size}
                  puts "DEBUG: Final update attributes = #{attributes.inspect}"
                  
                  begin
                    repository.update(device.id, **attributes)
                    puts "DEBUG: Update successful - next call will compare against this file size"
                  rescue => e
                    puts "DEBUG: Update failed: #{e.class} - #{e.message}"
                    puts "DEBUG: SQL error details: #{e.cause.inspect if e.respond_to?(:cause)}"
                  end
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
            # Ensure we have a device with the last_displayed_image_mtime attribute loaded
            unless device.respond_to?(:last_displayed_image_mtime)
              puts "DEBUG: Device missing last_displayed_image_mtime, reloading..."
              device = repository.find(device.id)
            end
            
            # Additional safety check - if the method exists but accessing it throws an error
            begin
              last_displayed_size = device.last_displayed_image_mtime  # Now stores file size
              puts "DEBUG: device.last_displayed_size = #{last_displayed_size.inspect}"
            rescue ROM::Struct::MissingAttribute => e
              puts "DEBUG: MissingAttribute error accessing last_displayed_image_mtime: #{e.message}"
              puts "DEBUG: Reloading device again..."
              device = repository.find(device.id)
              last_displayed_size = device.last_displayed_image_mtime rescue nil
              puts "DEBUG: After reload, last_displayed_size = #{last_displayed_size.inspect}"
            end
            
            return "sleep" unless last_displayed_size
            
            current_image_size = get_image_size(device, image)
            puts "DEBUG: current_image_size = #{current_image_size.inspect}"
            return "sleep" unless current_image_size
            
            # Simple file size comparison - no tolerance needed
            if current_image_size == last_displayed_size
              puts "DEBUG: Returning 'none' (same file size = same image)"
              "none"
            else
              puts "DEBUG: Returning 'sleep' (different file size = new/updated image)"
              "sleep"
            end
          end

          def get_image_size device, image
            return nil if image[:filename] == "setup"
            
            image_path = settings.screens_root.join(device.slug).join(image[:filename])
            return nil unless image_path.exist?
            
            # Use file size instead of timestamps - much more reliable
            image_path.size
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
