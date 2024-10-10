# frozen_string_literal: true

require 'dennis/validation_error'
require 'dennis/group_not_found_error'
require 'dennis/record'
require 'dennis/paginated_array'

module Dennis
  class Zone

    class << self

      def all(client, query: nil, view: nil, tags: nil, page: nil, per_page: nil)
        request = client.api.create_request(:get, 'zones')
        request.arguments[:query] = query if query
        request.arguments[:view] = view if view
        request.arguments[:tags] = tags if tags
        request.arguments[:page] = page if page
        request.arguments[:per_page] = per_page if per_page
        PaginatedArray.create(request.perform.hash, 'zones') do |hash|
          new(client, hash)
        end
      end

      def all_for_group(client, group, query: nil, view: nil, tags: nil, page: nil, per_page: nil)
        request = client.api.create_request(:get, 'groups/:group/zones')
        request.arguments[:group] = group
        request.arguments[:query] = query if query
        request.arguments[:view] = view if view
        request.arguments[:tags] = tags if tags
        request.arguments[:page] = page if page
        request.arguments[:per_page] = per_page if per_page
        PaginatedArray.create(request.perform.hash, 'zones') do |hash|
          new(client, hash)
        end
      end

      def find_by(client, field, value)
        request = client.api.create_request(:get, 'zones/:zone')
        request.arguments[:zone] = { field => value }
        new(client, request.perform.hash['zone'])
      rescue ApiaClient::RequestError => e
        e.code == 'zone_not_found' ? nil : raise
      end

      def create(client,
                 group:,
                 allow_sub_domains_of_zones_in_other_groups: nil,
                 **properties)
        request = client.api.create_request(:post, 'zones')
        request.arguments[:group] = group
        request.arguments[:properties] = properties
        unless allow_sub_domains_of_zones_in_other_groups.nil?
          request.arguments[:allow_sub_domains_of_zones_in_other_groups] = allow_sub_domains_of_zones_in_other_groups
        end
        new(client, request.perform.hash['zone'])
      rescue ApiaClient::RequestError => e
        raise GroupNotFoundError if e.code == 'group_not_found'
        raise ValidationError, e.detail['errors'] if e.code == 'validation_error'

        raise
      end

      def create_or_update(client, group:, **properties)
        if properties[:external_reference].nil?
          raise Dennis::ExternalReferenceRequiredError, 'An external_reference must be provided to use create_or_update'
        end

        zone = find_by(client, :external_reference, properties[:external_reference])
        if zone.nil?
          create(client, group: group, **properties)
        else
          zone.update(properties)
          zone
        end
      end

    end

    def initialize(client, hash)
      @client = client
      @hash = hash
    end

    def id
      @hash['id']
    end

    def name
      @hash['name']
    end

    def external_reference
      @hash['external_reference']
    end

    def nameservers_verified_at
      parse_time(@hash['nameservers_verified_at'])
    end

    def nameservers_checked_at
      parse_time(@hash['nameservers_checked_at'])
    end

    def nameservers_verified?
      @hash['nameservers_verified']
    end

    def txt_record_verified_at
      parse_time(@hash['txt_record_verified_at'])
    end

    def txt_record_checked_at
      parse_time(@hash['txt_record_checked_at'])
    end

    def txt_record_verified?
      parse_time(@hash['txt_record_verified'])
    end

    def verified?
      @hash['verified']
    end

    def always_verified?
      @hash['always_verified']
    end

    def reverse_dns?
      @hash['reverse_dns']
    end

    def stale_verification?
      @hash['stale_verification']
    end

    def default_ttl
      @hash['default_ttl']
    end

    def tags
      @hash['tags']
    end

    def group
      return @group if @group
      return nil unless @hash['group']

      @group = Group.new(@client, @hash['group'])
    end

    def created_at
      return nil if @hash['created_at'].nil?
      return @hash['created_at'] if @hash['created_at'].is_a?(Time)

      Time.at(@hash['created_at'])
    end

    def updated_at
      return nil if @hash['updated_at'].nil?
      return @hash['updated_at'] if @hash['updated_at'].is_a?(Time)

      Time.at(@hash['updated_at'])
    end

    def create_record(**properties)
      Record.create(@client, zone: { id: id }, **properties)
    end

    def create_or_update_record(**properties)
      Record.create_or_update(@client, id, **properties)
    end

    def records(**options)
      Record.all(@client, { id: id }, **options)
    end

    def record(value, field: :id)
      record = Record.find_by(@client, field, value)
      return nil if record.nil?
      return nil if record.zone.id != id

      record
    end

    def update(properties)
      req = @client.api.create_request(:patch, 'zones/:zone')
      req.arguments['zone'] = { id: id }
      req.arguments['properties'] = properties
      @hash = req.perform.hash['zone']
      true
    rescue ApiaClient::RequestError => e
      raise ValidationError, e.detail['errors'] if e.code == 'validation_error'

      raise
    end

    def delete
      req = @client.api.create_request(:delete, 'zones/:zone')
      req.arguments['zone'] = { id: id }
      req.perform
      true
    end

    def verify
      req = @client.api.create_request(:post, 'zones/:zone/verify')
      req.arguments['zone'] = { id: id }
      @hash.req.perform.hash['zone']
      verified?
    rescue ApiaClient::RequestError => e
      raise unless e.code == 'zone_already_verified'

      true
    end

    def verify_nameservers
      req = @client.api.create_request(:post, 'zones/:zone/verify_nameservers')
      req.arguments['zone'] = { id: id }
      @hash = req.perform.hash['zone']
      verified?
    rescue ApiaClient::RequestError => e
      raise unless e.code == 'nameservers_already_verified'

      true
    end

    private

    def parse_time(time)
      return nil if time.nil?
      return time if time.is_a?(Time)

      Time.at(time.to_i)
    end

  end
end
