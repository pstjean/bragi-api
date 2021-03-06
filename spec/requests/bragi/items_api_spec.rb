# frozen_string_literal: true

require 'rails_helper'

require 'support/mock_auth_plugin'

module Bragi
  RSpec.describe 'Items API', type: :request do
    before :each do
      Bragi.config do |c|
        c.auth_plugin = MockAuthPlugin.new
      end
    end

    let!(:user) { create :bragi_user, external_uid: '12345', secret_uid: 'ajhsdfghj' }

    describe 'GET #index' do
      it 'returns correct json api headers' do
        get '/items', headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(200)
        expect(response.content_type).to eq 'application/vnd.api+json'
      end

      it 'returns empty set' do
        get '/items', headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(200)

        json = JSON.parse response.body
        expect(json['data']).to eq []
      end

      context 'with audio_identifier filter' do
        let!(:items) { create_list :bragi_item, 10, user: user }
        let!(:item) { create :bragi_item, user: user, audio_identifier: '2017/01/01/blah1' }

        it 'returns the one item' do
          get '/items', params: { filter: { audio_identifier: '2017/01/01/blah1' } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 1

          first_item = json['data'].first
          expect(first_item.keys).to eq %w[id type attributes]
          expect(first_item['type']).to eq 'bragi_items'
          expect(first_item['attributes']['audio_identifier']).to eq '2017/01/01/blah1'
        end

        context 'with several items in filter' do
          let!(:item1) { create :bragi_item, user: user, audio_identifier: '2017/01/01/blah2' }

          it 'returns both items' do
            get '/items', params: { filter: { audio_identifier: ['2017/01/01/blah1', '2017/01/01/blah2'] } }, headers: { 'Authorization' => 'authorized_user' }
            expect(response).to have_http_status(200)

            json = JSON.parse response.body
            expect(json['data'].size).to eq 2

            first_item = json['data'].first
            expect(first_item.keys).to eq %w[id type attributes]
            expect(first_item['type']).to eq 'bragi_items'
            expect(first_item['attributes']['audio_identifier']).to eq '2017/01/01/blah1'
            expect(json['data'][1]['attributes']['audio_identifier']).to eq '2017/01/01/blah2'
          end
        end
      end

      context 'with multiple items' do
        let!(:items) { create_list :bragi_item, 10, user: user }

        it 'returns several items' do
          get '/items', headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 10

          first_item = json['data'].first
          expect(first_item.keys).to eq %w[id type attributes]
          expect(first_item['type']).to eq 'bragi_items'
        end
      end

      context 'with unauthorized user' do
        it 'returns error' do
          expect do
            get '/items', headers: { 'Authorization' => 'unauthorized_user' }
          end.to raise_exception Bragi::ApplicationController::InvalidAuth
        end
      end

      context 'with more than 50 items' do
        let!(:items) { create_list :bragi_item, 61, user: user }

        it 'returns page 2' do
          get '/items', params: { page: { number: 2 } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 11
          expect(json['links'].keys).to include 'self'
          expect(json['links'].keys).to include 'prev'
          expect(json['links'].keys).to include 'first'
          expect(json['meta']['current_page']).to eq 2
          expect(json['meta']['total_pages']).to eq 2
          expect(json['meta']['total_count']).to eq 61
        end

        it 'shows next and last links on page 1' do
          get '/items', params: { page: { number: 1 } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 50
          expect(json['links'].keys).to include 'self'
          expect(json['links'].keys).to include 'next'
          expect(json['links'].keys).to include 'last'
          expect(json['meta']['current_page']).to eq 1
        end

        it 'allows defined page size' do
          get '/items', params: { page: { number: 1, size: 20 } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 20
        end
      end

      context 'with a mixed set of played and unplayed' do
        let!(:item1) { create :bragi_item, user: user, position: 3 }
        let!(:item2) { create :bragi_played_item, user: user, finished: '2017-01-01T00:04:00Z' }
        let!(:item3) { create :bragi_played_item, user: user, finished: '2017-01-01T00:03:00Z' }
        let!(:item4) { create :bragi_played_item, user: user, finished: '2017-01-01T00:00:00Z' }
        let!(:item5) { create :bragi_item, user: user, position: 2, status: 'playing' }
        let!(:item6) { create :bragi_item, user: user, position: 1 }
        let!(:item7) { create :bragi_item, user: user, position: 4 }

        it 'returns unplayed by position followed by played by finished time' do
          get '/items', headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 7
          expect(json['data'][0]['id']).to eq item6.id.to_s
          expect(json['data'][1]['id']).to eq item5.id.to_s
          expect(json['data'][2]['id']).to eq item1.id.to_s
          expect(json['data'][3]['id']).to eq item7.id.to_s
          expect(json['data'][4]['id']).to eq item4.id.to_s
          expect(json['data'][5]['id']).to eq item3.id.to_s
          expect(json['data'][6]['id']).to eq item2.id.to_s
        end

        it 'fetches by after_id' do
          get '/items', params: { filter: { after_id: item6.id } }, headers: { 'Authorization' => 'authorized_user' }

          expect(response).to have_http_status(200)
          json = JSON.parse response.body
          expect(json['data'].size).to eq 3
          expect(json['data'][0]['id']).to eq item5.id.to_s
          expect(json['data'][1]['id']).to eq item1.id.to_s
          expect(json['data'][2]['id']).to eq item7.id.to_s
        end

        it 'fetches by after_id and status' do
          get '/items', params: { filter: { after_id: item6.id, status: 'unplayed' } }, headers: { 'Authorization' => 'authorized_user' }

          expect(response).to have_http_status(200)
          json = JSON.parse response.body
          expect(json['data'].size).to eq 2
          expect(json['data'][0]['id']).to eq item1.id.to_s
          expect(json['data'][1]['id']).to eq item7.id.to_s
        end

        it 'returns no items if after_id is last item' do
          get '/items', params: { filter: { after_id: item7.id } }, headers: { 'Authorization' => 'authorized_user' }

          expect(response).to have_http_status(200)
          json = JSON.parse response.body
          expect(json['data'].size).to eq 0
        end
      end

      context 'with more than 100 items' do
        let!(:items) { create_list :bragi_item, 110, user: user }
        it 'limits defined page size' do
          get '/items', params: { page: { number: 1, size: 1000 } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 100
        end
      end

      context 'with a mix of sources and statuses' do
        let!(:items1) { create_list :bragi_item, 10, user: user, source: 'blah' }
        let!(:items2) { create_list :bragi_played_item, 10, user: user, source: 'blah' }
        let!(:items3) { create_list :bragi_item, 10, user: user, source: 'blah1' }
        let!(:items4) { create_list :bragi_played_item, 10, user: user, source: 'blah1' }

        it 'fetches by source' do
          get '/items', params: { filter: { source: 'blah' } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 20
          json['data'].each do |item|
            expect(item['attributes']['source']).to eq 'blah'
          end
        end

        it 'fetches by status' do
          get '/items', params: { filter: { status: 'played' } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 20
          json['data'].each do |item|
            expect(item['attributes']['status']).to eq 'played'
          end
        end

        it 'fetches by array of statuses' do
          get '/items', params: { filter: { status: %w[played playing] } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 20
          json['data'].each do |item|
            expect(item['attributes']['status']).to eq 'played'
          end
        end

        it 'fetches by source and status' do
          get '/items', params: { filter: { status: 'played', source: 'blah1' } }, headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].size).to eq 10
          json['data'].each do |item|
            expect(item['attributes']['status']).to eq 'played'
            expect(item['attributes']['source']).to eq 'blah1'
          end
        end
      end
    end

    describe 'GET #show' do
      it 'returns 404' do
        expect do
          get '/items/12345', headers: { 'Authorization' => 'authorized_user' }
        end.to raise_exception ActiveRecord::RecordNotFound
      end

      context 'with item' do
        let!(:item) { create :bragi_item, user: user, audio_identifier: '01/01/01/blah' }

        it 'returns item' do
          get "/items/#{item.id}", headers: { 'Authorization' => 'authorized_user' }
          expect(response).to have_http_status(200)

          json = JSON.parse response.body
          expect(json['data'].keys).to eq %w[id type attributes]
          expect(json['data']['id']).to eq item.id.to_s
          expect(json['data']['type']).to eq 'bragi_items'
        end
      end

      context 'with unauthorized user' do
        it 'returns error' do
          expect do
            get '/items/123', headers: { 'Authorization' => 'unauthorized_user' }
          end.to raise_exception Bragi::ApplicationController::InvalidAuth
        end
      end
    end

    describe 'PATCH #update' do
      let!(:item) { create :bragi_item, user: user }

      it 'supports 404' do
        expect do
          patch '/items/123456', headers: { 'Authorization' => 'authorized_user' }
        end.to raise_exception ActiveRecord::RecordNotFound
      end

      it 'sets finished when played and not provided' do
        attrs = {
          data: {
            type: 'bragi-item',
            attributes: {
              status: :played
            }
          }
        }

        patch "/items/#{item.id}", params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(204)

        item.reload

        expect(item.played?).to eq true
        expect(item.finished).to_not be_nil
      end

      it 'does not allow changing the audio_identifier' do
        attrs = {
          data: {
            type: 'bragi-item',
            attributes: {
              audio_identifier: 'ajshgdfkjhagsf'
            }
          }
        }

        patch "/items/#{item.id}", params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(204)

        item.reload

        expect(item.audio_identifier).to_not eq attrs[:audio_identifier]
      end

      it 'updates existing individual field' do
        attrs = {
          data: {
            type: 'bragi-item',
            attributes: {
              playtime: 123_456
            }
          }
        }

        patch "/items/#{item.id}", params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(204)

        item.reload

        expect(item.playtime).to eq 123_456
      end

      it 'resorts when placed after' do
        second_item = create :bragi_item, user: user, after: item

        expect(item.after).to be_nil
        expect(second_item.after).to eq item

        attrs = {
          data: {
            type: 'bragi-item',
            attributes: {
              after_id: second_item.id
            }
          }
        }

        patch "/items/#{item.id}", params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(204)

        item.reload
        second_item.reload

        expect(item.position).to be > second_item.position
        expect(item.after).to eq second_item
      end

      it 'updates existing with field errors' do
        attrs = {
          data: {
            type: 'bragi-item',
            attributes: {
              audio_title: ''
            }
          }
        }
        patch "/items/#{item.id}", params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(400)

        json = JSON.parse(response.body)
        expect(json['errors'][0]['source']['pointer']).to eq '/data/attributes/audio_title'
        expect(json['errors'][0]['detail']).to eq "can't be blank"
      end

      context 'with unauthorized user' do
        it 'returns error' do
          expect do
            patch '/items/123', headers: { 'Authorization' => 'unauthorized_user' }
          end.to raise_exception Bragi::ApplicationController::InvalidAuth
        end
      end
    end

    describe 'POST #create' do
      let(:item_attributes) { attributes_for :bragi_item, audio_identifier: 'blah1234' }

      it 'POSTs new' do
        attrs = {
          data: {
            type: 'bragi-item',
            attributes: item_attributes
          }
        }

        post '/items', params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(200)

        expect(Item.count).to eq 1
        first_db_item = Item.first

        json = JSON.parse(response.body)
        expect(json['data']['id']).to eq first_db_item.id.to_s
      end

      it 'POSTs existing' do
        preexisting_item = create :bragi_item, audio_identifier: 'blah1234', user: user

        attrs = {
          data: {
            type: 'bragi-item',
            attributes: item_attributes
          }
        }

        post '/items', params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(200)

        preexisting_item.reload

        expect(Item.count).to eq 1
        expect(Item.first).to eq preexisting_item

        json = JSON.parse(response.body)
        expect(json['data']['id']).to eq preexisting_item.id.to_s
      end

      it 'POSTs new with field errors' do
        item_attrs = item_attributes.dup
        item_attrs[:audio_identifier] = ''

        attrs = {
          data: {
            type: 'bragi-item',
            attributes: item_attrs
          }
        }
        post '/items', params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(400)

        expect(Item.count).to eq 0

        json = JSON.parse(response.body)
        expect(json['errors'][0]['source']['pointer']).to eq '/data/attributes/audio_identifier'
        expect(json['errors'][0]['detail']).to eq "can't be blank"
      end

      it 'POSTs new after existing' do
        item = create :bragi_item, user: user

        attrs = {
          data: {
            type: 'bragi-item',
            attributes: item_attributes.merge(after_id: item.id)
          }
        }

        post '/items', params: attrs, headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(200)

        expect(Item.count).to eq 2
        new_db_item = Item.last

        expect(new_db_item.position).to be > item.position
      end

      # it 'POSTs existing with older play_start_time' do
      #   preexisting_item = create :bragi_item, audio_identifier: 'blah1234', user: user, playtime: 1234

      #   attrs = item_attributes.dup
      #   attrs[:playtime] = 123
      #   post '/items', params: attrs, headers: { 'Authorization' => 'authorized_user' }
      #   expect(response).to have_http_status(200)

      #   preexisting_item.reload
      #   expect(preexisting_item.playtime).to eq 1234
      # end

      # it 'POSTs existing with newer play_start_time' do
      #   preexisting_item = create :bragi_item, audio_identifier: 'blah1234', user: user, playtime: 1234

      #   attrs = item_attributes.dup
      #   attrs[:playtime] = 12345
      #   post '/items', params: attrs, headers: { 'Authorization' => 'authorized_user' }
      #   expect(response).to have_http_status(200)

      #   preexisting_item.reload
      #   expect(preexisting_item.playtime).to eq 12345
      # end

      context 'with unauthorized user' do
        it 'returns error' do
          expect do
            post '/items', headers: { 'Authorization' => 'unauthorized_user' }
          end.to raise_exception Bragi::ApplicationController::InvalidAuth
        end
      end
    end

    describe 'DELETE #destroy' do
      let!(:item) { create :bragi_item, audio_identifier: '12345', user: user }

      it 'supports 404' do
        expect do
          delete '/items/123456', headers: { 'Authorization' => 'authorized_user' }
        end.to raise_exception ActiveRecord::RecordNotFound
      end

      it 'supports deletion' do
        delete "/items/#{item.id}", headers: { 'Authorization' => 'authorized_user' }
        expect(response).to have_http_status(204)
        expect(Item.count).to eq 0
      end

      context 'with unauthorized user' do
        it 'returns error' do
          expect do
            delete "/items/#{item.id}", headers: { 'Authorization' => 'unauthorized_user' }
          end.to raise_exception Bragi::ApplicationController::InvalidAuth
        end
      end
    end

    describe 'GET #podcast' do
      let!(:items) { create_list :bragi_item, 10, user: user }

      context 'with secret uid' do
        it 'returns podcast' do
          get '/items/ajhsdfghj/podcast.xml'
          expect(response).to have_http_status(200)
          # puts response.body
        end
      end

      context 'with invalid id' do
        it 'returns 404' do
          expect do
            get '/items/noid/podcast.xml'
          end.to raise_exception ActiveRecord::RecordNotFound
        end
      end
    end
  end
end
