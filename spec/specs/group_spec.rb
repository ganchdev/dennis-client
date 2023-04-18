# frozen_string_literal: true

require 'spec_helper'
require 'pry'

module Dennis

  describe Group do
    include_context 'with client'

    describe '.all' do
      it 'returns an array of all groups' do
        VCR.use_cassette('group-all') do
          groups = described_class.all(@client)
          expect(groups).to be_a Array
        end
      end

      it 'returns a pagination information' do
        VCR.use_cassette('group-all') do
          zones = described_class.all(@client)
          expect(zones.pagination.current_page).to eq 1
          expect(zones.pagination.per_page).to eq 30
          expect(zones.pagination.total_pages).to eq 1
        end
      end

      it 'returns can control the number of items per page' do
        VCR.use_cassette('group-all-per-page') do
          zones = described_class.all(@client, per_page: 2)
          expect(zones.pagination.current_page).to eq 1
          expect(zones.pagination.per_page).to eq 2
          expect(zones.pagination.total_pages).to be > 1
        end
      end

      it 'returns can control which page is returned' do
        VCR.use_cassette('group-all-page') do
          zones = described_class.all(@client, per_page: 2, page: 2)
          expect(zones.pagination.current_page).to eq 2
          expect(zones.pagination.per_page).to eq 2
          expect(zones.pagination.total_pages).to be > 1
        end
      end
    end

    describe '.find_by' do
      it 'can find groups by ID' do
        VCR.use_cassette('group-find-by-id') do
          group = described_class.find_by(@client, :id, 2)
          expect(group).to be_a Group
          expect(group).to have_attributes(id: 2, name: 'Another Group', external_reference: 'another')
        end
      end

      it 'can find groups by external reference' do
        VCR.use_cassette('group-find-by-ext-ref') do
          group = described_class.find_by(@client, :external_reference, 'another')
          expect(group).to be_a Group
          expect(group).to have_attributes(id: 2, name: 'Another Group', external_reference: 'another')
        end
      end

      it 'returns nil if no group is found' do
        VCR.use_cassette('group-find-by-id-missing') do
          group = described_class.find_by(@client, :id, 99_999)
          expect(group).to be nil
        end
      end

      it 'raises an error if another issue arises' do
        VCR.use_cassette('group-find-by-invalid-column') do
          expect { described_class.find_by(@client, :invalid, '') }.to raise_error(ApiaClient::RequestError) do |e|
            expect(e.status).to eq 400
            expect(e.code).to eq 'invalid_argument'
          end
        end
      end
    end

    describe '.create' do
      it 'returns the newly created group' do
        VCR.use_cassette('group-create') do
          group = described_class.create(@client, name: 'Apple Group', external_reference: 'apples', nameservers: %w[laura.example.com simon.example.com])
          expect(group).to be_a Group
          expect(group).to have_attributes name: 'Apple Group', external_reference: 'apples'
          expect(group.nameservers).to be_a Array
        end
      end

      it 'has nameservers after creation' do
        VCR.use_cassette('group-create') do
          group = described_class.create(@client, name: 'Apple Group', external_reference: 'apples')
          expect(group).to be_a Group
          expect(group.nameservers).to be_a Array
          expect(group.nameservers.size).to eq 2
          expect(group.nameservers).to all be_a Nameserver
        end
      end

      it 'raises a validation error if there is an issue' do
        VCR.use_cassette('group-create-validation-error') do
          expect do
            described_class.create(@client, name: '')
          end.to raise_error ValidationError do |e|
            expect(e.errors).to match array_including(
              having_attributes(attribute: 'name', type: 'blank')
            )
          end
        end
      end
    end

    describe '#update' do
      it 'updates the group' do
        VCR.use_cassette('group-update') do
          group = described_class.find_by(@client, :id, 1)
          group.update(name: 'Renamed Group', external_reference: 'with-ref')
          expect(group.name).to eq 'Renamed Group'
          expect(group.external_reference).to eq 'with-ref'
        end

        # Verify with a new cassette to trigger a new update
        VCR.use_cassette('group-update-after-update-complete') do
          group = described_class.find_by(@client, :id, 1)
          expect(group.name).to eq 'Renamed Group'
          expect(group.external_reference).to eq 'with-ref'
        end
      end

      it 'raises a validation error if appropriate' do
        VCR.use_cassette('group-update-with-validation-error') do
          group = described_class.find_by(@client, :id, 1)
          expect { group.update(name: '') }.to raise_error ValidationError do |e|
            expect(e.errors).to match array_including(
              having_attributes(attribute: 'name', type: 'blank')
            )
          end
        end
      end
    end

    describe '#delete' do
      it 'deletes the group' do
        VCR.use_cassette('group-delete') do
          group = described_class.find_by(@client, :id, 3)
          group.delete
        end

        VCR.use_cassette('group-delete-verify') do
          group = described_class.find_by(@client, :id, 3)
          expect(group).to be nil
        end
      end
    end

    describe '#create_zone' do
      it 'creates a zone' do
        VCR.use_cassette('group-find-by-id') do
          group = described_class.find_by(@client, :id, 2)
          expect(Zone).to receive(:create) do |_, options|
            expect(options[:group]).to eq({ id: 2 })
            expect(options[:name]).to eq 'example.com'
            expect(options[:external_reference]).to eq 'blah'
          end
          group.create_zone(name: 'example.com', external_reference: 'blah')
        end
      end
    end

    describe '#zones' do
      it 'returns an array of all zones for a group' do
        VCR.use_cassette('group-find-by-id') do
          group = described_class.find_by(@client, :id, 2)
          expect(Zone).to receive(:all_for_group) do |_, g|
            expect(g).to eq({ id: 2 })
          end
          group.zones
        end
      end
    end
  end

end
