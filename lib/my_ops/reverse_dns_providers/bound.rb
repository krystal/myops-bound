require 'moonrope_client'

module MyOps
  module ReverseDNSProviders
    class Bound < MyOps::ReverseDNSProvider

      class BoundError < MyOps::Error; end

      self.provider_name = "Bound"
      self.provider_description = "Bound is a self hosted web interface on top of BIND and can provide support for publishing reverse DNS records."

      def update(ip_address, hostname)
        # Remove any trailing dots which might slip in
        hostname = hostname ? hostname.gsub(/\.+\z/, '') : nil

        # Get the zone name and record name for this IP address
        zone_name, record_name = reverse_zone_name(ip_address)
        self.class.logger.info "Updating #{ip_address.to_s} to '#{hostname}'".blue
        self.class.logger.debug "Zone name: '#{zone_name}' // Record: '#{record_name}'"

        # Get the correct zone ID
        zone_id = find_or_create_zone(zone_name)

        # Create/update/delete the record
        update_record(zone_id, record_name, hostname)
      end

      def self.config
        MyOps.module_config['myops-bound']
      end

      def self.client
        @client ||= begin
          headers = {'X-Auth-Token' => config.api_key}
          MoonropeClient::Connection.new(config.host, :headers => headers, :ssl => config.ssl, :port => config.port)
        end
      end

      def self.logger
        @logger ||= Logger.new(Rails.root.join('log', 'bound.log'))
      end

      private

      # Returns the zone name which this record needs to be inserted within
      def reverse_zone_name(ip_address)
        if ip_address.ipv4?
          zone = ip_address.reverse.gsub(/\A(\d+)\./, '')
          [zone, $1]
        else
          zone = ip_address.reverse.gsub(/\A((\d+\.){16})/, '')
          [zone, $1.gsub(/\.\z/, '')]
        end
      end

      # Find or create an existing zone which can be used for this record.
      # Returns the ID of the zone
      def find_or_create_zone(zone_name)
        list_result = self.class.client.zones.list
        unless list_result.success?
          self.class.logger.fatal error_text = "Couldn't get a list of zones from the Bound API"
          self.class.logger.fatal list_result.inspect
          raise BoundError, error_text
        end

        existing_zones = list_result.data
        if existing_zone = existing_zones.find { |zone| zone['name'] == zone_name}
          id = existing_zone['id']
          self.class.logger.debug "Found existing zone with name '#{zone_name}' with ID #{id}"
          id
        else
          self.class.logger.debug "No zone exists with '#{zone_name}'"
          create_request = self.class.client.zones.create(:name => zone_name)
          unless create_request
            self.class.logger.fatal error_text = "Couldn't create zone with name '#{zone_name}'"
            self.class.logger.fatal create_request.inspect
            raise BoundError, error_text
          end
          id = create_request.data['id']
          self.class.logger.info "Created new zone '#{zone_name}' with ID #{id}".green
          id
        end
      rescue MoonropeClient::Error => e
        self.class.logger.fatal "Error talking to Bound API when creating/finding existing zone"
        self.class.logger.fatal "#{e.class}: #{e.message}"
        e.backtrace[0,5].each { |line| self.class.logger.fatal line }
        raise BoundError, "Error talking to the Bound API. See bound.log for details."
      end

      # Find or create an existing record and update and/or create it as appropriate
      def update_record(zone_id, record_name, hostname)
        # Add a trailing dot to all hostnames
        hostname = hostname.blank? ? nil : hostname + "."

        list_result = self.class.client.records.list(:zone_id => zone_id)
        unless list_result.success?
          self.class.logger.fatal error_text = "Couldn't get a list of records for zone '#{zone_id}' from the Bound API"
          self.class.logger.fatal list_result.inspect
          raise BoundError, error_text
        end

        ptr_class_name = 'Bound::BuiltinRecordTypes::PTR'

        existing_records = list_result.data
        existing_record = existing_records.find { |record| record['name'] == record_name && record['type']['class'] == ptr_class_name}
        if existing_record && hostname
          id = existing_record['id']
          self.class.logger.debug "Found existing record with name '#{record_name}' with ID #{id}. Updating it."
          update_result = self.class.client.records.update(:record_id => id, :form_data => {'name' => hostname})
          unless update_result.success?
            self.class.logger.fatal error_text = "Couldn't update record with name '#{record_name}' (ID #{id}) on zone '#{zone_name}'"
            self.class.logger.fatal create_request.inspect
            raise BoundError, error_text
          end
          self.class.logger.info "Updated record with ID #{id} to '#{hostname}'".green
          id
        elsif existing_record && hostname.nil?
          # Delete the existing record
          id = existing_record['id']
          self.class.logger.debug "Found existing record with name '#{record_name}' with ID #{id}. Removing it."
          delete_result = self.class.client.records.destroy(:record_id => id)
          unless delete_result.success?
            self.class.logger.fatal error_text = "Couldn't deleted record with name '#{record_name}' (ID #{id}) on zone '#{zone_name}'"
            self.class.logger.fatal delete_result.inspect
            raise BoundError, error_text
          end
          self.class.logger.info "Deleted record with ID #{id}".green
          nil
        elsif hostname
          self.class.logger.debug "No record exists with name '#{record_name}'. Creating one."
          create_result = self.class.client.records.create(:zone_id => zone_id, :name => record_name, :type => ptr_class_name, :form_data => {'name' => hostname})
          unless create_result.success?
            self.class.logger.fatal error_text = "Couldn't create record with name '#{record_name}' on zone '#{zone_name}'"
            self.class.logger.fatal create_request.inspect
            raise BoundError, error_text
          end
          id = create_result.data['id']
          self.class.logger.info "Created record with ID #{id} to '#{hostname}'".green
          id
        else
          # Nothing to do at all
          self.class.logger.info "No record is needed.".green
          nil
        end
      end

    end
  end
end
