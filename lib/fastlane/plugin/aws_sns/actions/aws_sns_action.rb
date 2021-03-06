require 'aws-sdk'

module Fastlane
  module Actions
    module SharedValues
      AWS_SNS_PLATFORM_APPLICATION_ARN = :AWS_SNS_PLATFORM_APPLICATION_ARN
    end

    class AwsSnsAction < Action
      def self.run(params)

        access_key = params[:access_key]
        secret_access_key = params[:secret_access_key]
        region = params[:region]

        platform = params[:platform]
        platform_name = params[:platform_name]

        platform_apns_private_key_path = params[:platform_apns_private_key_path]
        platform_apns_private_key_password = params[:platform_apns_private_key_password]

        platform_gcm_api_key = params[:platform_gcm_api_key]

        UI.user_error!("No S3 access key given, pass using `access_key: 'key'`") unless access_key.to_s.length > 0
        UI.user_error!("No S3 secret access key given, pass using `secret_access_key: 'secret key'`") unless secret_access_key.to_s.length > 0
        UI.user_error!("No S3 region given, pass using `region: 'region'`") unless region.to_s.length > 0
        UI.user_error!("No S3 region given, pass using `platform: 'platform'`") unless platform.to_s.length > 0
        UI.user_error!("No S3 region given, pass using `platform_name: 'platform_name'`") unless platform_name.to_s.length > 0

        #
        # Initialize AWS client
        #
        client = Aws::SNS::Client.new(
          access_key_id: access_key,
          secret_access_key: secret_access_key,
          region: region
        )

        #
        # Create APNS and GCM attributes
        #
        if ['APNS', 'APNS_SANDBOX'].include?(platform)
          UI.user_error!("Platform private key does not exist at path: #{platform_apns_private_key_path}") unless File.exist?(platform_apns_private_key_path)

          file = File.read(platform_apns_private_key_path)
          p12 = OpenSSL::PKCS12.new(file, platform_apns_private_key_password)
          cert = p12.certificate

          attributes = {
            'PlatformCredential': p12.key.to_s,
            'PlatformPrincipal': cert.to_s
          }
        elsif ['GCM'].include?(platform) && !platform_gcm_api_key.nil?
          attributes = {
            'PlatformCredential': platform_gcm_api_key
          }
        end

        #
        #
        #
        UI.crash!("Unable to create any attributes to create platform application") unless attributes
        begin
          resp = client.create_platform_application({
            name: platform_name,
            platform: platform,
            attributes: attributes,
          })
          arn = resp.platform_application_arn

          Actions.lane_context[SharedValues::AWS_SNS_PLATFORM_APPLICATION_ARN] = arn
          ENV[SharedValues::AWS_SNS_PLATFORM_APPLICATION_ARN.to_s] = arn
        rescue => error
          UI.crash!("Create Platform Error: #{error.inspect}")
        end

        Actions.lane_context[SharedValues::AWS_SNS_PLATFORM_APPLICATION_ARN]
      end

      def self.description
        "Creates AWS SNS platform applications"
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.return_value
        "Platform Application ARN"
      end

      def self.details
        "Creates AWS SNS platform applications for iOS and Android"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :access_key,
                                       env_name: "AWS_SNS_ACCESS_KEY",
                                       description: "AWS Access Key ID",
                                       optional: false,
                                       default_value: ENV['AWS_ACCESS_KEY_ID']),
          FastlaneCore::ConfigItem.new(key: :secret_access_key,
                                       env_name: "AWS_SNS_SECRET_ACCESS_KEY",
                                       description: "AWS Secret Access Key",
                                       optional: false,
                                       default_value: ENV['AWS_SECRET_ACCESS_KEY']),
          FastlaneCore::ConfigItem.new(key: :region,
                                      env_name: "AWS_SNS_REGION",
                                      description: "AWS Region",
                                      optional: false,
                                      default_value: ENV['AWS_REGION']),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       env_name: "AWS_SNS_PLATFORM",
                                       description: "AWS Platform",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Invalid platform #{value}") unless ['APNS', 'APNS_SANDBOX', 'GCM'].include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :platform_name,
                                      env_name: "AWS_SNS_PLATFORM_NAME",
                                      description: "AWS Platform Name",
                                      optional: false),
          FastlaneCore::ConfigItem.new(key: :platform_apns_private_key_path,
                                      env_name: "AWS_SNS_PLATFORM_APNS_PRIVATE_KEY_PATH",
                                      description: "AWS Platform APNS Private Key Path",
                                      optional: true),
          FastlaneCore::ConfigItem.new(key: :platform_apns_private_key_password,
                                      env_name: "AWS_SNS_PLATFORM_APNS_PRIVATE_KEY_PASSWORD",
                                      description: "AWS Platform APNS Private Key Password",
                                      optional: true,
                                      default_value: ""),
          FastlaneCore::ConfigItem.new(key: :platform_gcm_api_key,
                                      env_name: "AWS_SNS_PLATFORM_GCM_API_KEY",
                                      description: "AWS Platform GCM API KEY",
                                      optional: true)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
