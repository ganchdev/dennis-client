# frozen_string_literal: true

require 'dennis/nameserver'
require 'dennis/validation_error'

module Dennis
  class Group

    class << self

      def all(client)
        groups = client.api.perform(:get, 'groups')
        groups.hash['groups'].map { |hash| new(client, hash) }
      end

      def find_by(client, field, value)
        request = client.api.create_request(:get, 'groups/:group')
        request.arguments[:group] = { field => value }
        Group.new(client, request.perform.hash['group'])
      rescue RapidAPI::RequestError => e
        e.code == 'group_not_found' ? nil : raise
      end

      def create(client, name:, external_reference: nil)
        request = client.api.create_request(:post, 'groups')
        request.arguments[:properties] = { name: name, external_reference: external_reference }
        Group.new(client, request.perform.hash['group'])
      rescue RapidAPI::RequestError => e
        raise ValidationError, e.detail['errors'] if e.code == 'validation_error'

        raise
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

    def nameservers
      @nameservers ||= @hash['nameservers'].map do |hash|
        Nameserver.new(@client, hash)
      end
    end

    def create_zone(**properties)
      Zone.create(@client, group: { id: id }, **properties)
    end

    def create_or_update_zone(**properties)
      Zone.create_or_update(@client, group: { id: id }, **properties)
    end

    def zones
      Zone.all_for_group(@client, { id: id })
    end

    def update(properties)
      req = @client.api.create_request(:patch, 'groups/:group')
      req.arguments['group'] = { id: id }
      req.arguments['properties'] = properties
      @hash = req.perform.hash['group']
      true
    rescue RapidAPI::RequestError => e
      raise ValidationError, e.detail['errors'] if e.code == 'validation_error'

      raise
    end

    def delete
      req = @client.api.create_request(:delete, 'groups/:group')
      req.arguments['group'] = { id: id }
      req.perform
      true
    end

  end
end
