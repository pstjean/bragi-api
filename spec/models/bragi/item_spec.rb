# frozen_string_literal: true

# == Schema Information
#
# Table name: bragi_items
#
#  id                :integer          not null, primary key
#  audio_identifier  :string(255)      not null
#  audio_url         :string(255)      not null
#  audio_title       :string(255)      not null
#  audio_description :text(65535)
#  audio_hosts       :text(65535)
#  audio_program     :string(255)
#  origin_url        :string(255)
#  source            :string(255)      not null
#  playtime          :integer          not null
#  status            :integer          not null
#  finished          :datetime
#  bragi_user_id     :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  position          :integer
#

require 'rails_helper'

module Bragi
  RSpec.describe Item, type: :model do
    let(:user) { create :bragi_user }
    let(:status) { :unplayed }
    let(:item) { build :bragi_item, status: status, user: user, position: 1 }

    describe '#finished' do
      context 'with played status' do
        let(:status) { :played }

        it 'allows a finished datetime' do
          item.finished = Time.zone.now
          item.position = nil
          expect(item).to be_valid
        end

        it 'requires a finished datetime' do
          expect(item).to_not be_valid
          expect(item.errors[:finished]).to eq ["can't be blank"]
        end
      end

      (Item.statuses.keys - ['played']).each do |enum_status|
        context "with #{enum_status} status" do
          let(:status) { enum_status }

          it 'does not allow a finished datetime' do
            item.finished = Time.zone.now
            expect(item).to_not be_valid
          end
        end
      end
    end

    describe '#after' do
      let(:position) { 1 }
      let(:finished) { nil }
      let(:item) { create :bragi_item, status: status, user: user, position: position, finished: finished }

      subject { item.after }

      context 'with one item' do
        it { is_expected.to be_nil }
      end

      context 'with an item before' do
        let(:position) { 2 }
        let!(:before_item) { create :bragi_item, status: :unplayed, user: user, position: 1 }
        let!(:before_item1) { create :bragi_item, status: :unplayed, user: user, position: 0 }

        it 'lists that item as the thing it is after' do
          expect(subject).to eq before_item
        end
      end

      context 'with an item after' do
        let!(:before_item) { create :bragi_item, status: :unplayed, user: user, position: 2 }

        it { is_expected.to be_nil }
      end

      context 'when position is null' do
        let(:position) { nil }
        let(:status) { :played }
        let(:finished) { Time.zone.now }

        it 'is always null' do
          expect(subject).to be_nil
        end
      end
    end

    describe '#after_id' do
      let(:position) { 1 }
      let(:finished) { nil }
      let(:item) { create :bragi_item, status: status, user: user, position: position, finished: finished }

      subject { item.after_id }

      context 'with one item' do
        it { is_expected.to be_nil }
      end

      context 'with an item before' do
        let(:position) { 2 }
        let!(:before_item) { create :bragi_item, status: :unplayed, user: user, position: 1 }
        let!(:before_item1) { create :bragi_item, status: :unplayed, user: user, position: 0 }

        it 'lists that item as the thing it is after' do
          expect(subject).to eq before_item.id
        end
      end
    end

    describe '#after=' do
      it 'inserts at the beginning with no other record' do
        item.after = nil
        item.save!
        expect(item.position).to eq 0
      end

      it 'inserts at the beginning with other record' do
        create :bragi_item, status: :unplayed, user: user, position: 0
        item.after = nil
        item.save!
        expect(item.position).to eq(-10)
      end

      it 'inserts at the end' do
        other_item = create :bragi_item, status: :unplayed, user: user, position: 0
        item.after = other_item
        item.save!
        expect(item.position).to eq 10
      end

      it 'inserts in the middle with space' do
        item1 = create :bragi_item, status: :unplayed, user: user, position: 0
        create :bragi_item, status: :unplayed, user: user, position: 10
        item.after = item1
        item.save!
        expect(item.position).to eq 5
      end

      it 'inserts in the middle with no space' do
        item1 = create :bragi_item, status: :unplayed, user: user, position: 0
        item2 = create :bragi_item, status: :unplayed, user: user, position: 1
        item.after = item1
        item.save!
        item1.reload
        item2.reload
        expect(item.position).to eq 5
        expect(item1.position).to eq 0
        expect(item2.position).to eq 10
      end

      it 'inserts after item belonging to different user' do
        user2 = create :bragi_user
        other_item = create :bragi_item, status: :unplayed, user: user2, position: 0
        item.after = other_item
        expect do
          item.save!
        end.to raise_error Bragi::Item::WrongUserAfterError
      end

      it 'inserts at the end with no space afterwards (maximum)' do
        other_item = create :bragi_item, status: :unplayed, user: user, position: 2_147_483_647
        item.after = other_item
        expect do
          item.save!
        end.to raise_error ActiveModel::RangeError
      end

      it 'inserts at the beginning with no space before (minimum)' do
        create :bragi_item, status: :unplayed, user: user, position: -2_147_483_648
        item.after = nil
        expect do
          item.save!
        end.to raise_error ActiveModel::RangeError
      end

      it 'throws error if `after` item unpersisted' do
        item1 = build :bragi_item, status: :unplayed, user: user, position: 0
        item.after = item1
        expect do
          item.save!
        end.to raise_error Bragi::Item::AfterItemUnpersistedError
      end

      it 'ignores `after` if played and first item' do
        item.finished = Time.zone.now
        item.status = :played
        item.after = nil
        item.position = nil
        item.save!
        expect(item.position).to be_nil
      end

      it 'ignores `after` if played' do
        item1 = create :bragi_item, status: :unplayed, user: user, position: 0
        item.finished = Time.zone.now
        item.status = :played
        item.position = nil
        item.after = item1
        item.save!
        expect(item.position).to be_nil
      end

      it 'ignores `after` if other item played' do
        item1 = create :bragi_played_item, user: user
        item.after = item1
        item.save!
        expect(item.position).to be_nil
      end

      it 'shows dirty `after` before save' do
        item2 = build :bragi_item, user: user, status: :unplayed
        item.after = item2
        expect(item.after).to eq item2
      end

      it 'defaults to the very end' do
        item.save!
        item1 = create :bragi_item, user: user, status: :unplayed, position: nil
        expect(item1.position).to eq 11
      end
    end

    describe '#after=' do
      it 'inserts at the beginning with no other record' do
        item.after_id = nil
        item.save!
        expect(item.position).to eq 0
      end

      it 'inserts at the end' do
        other_item = create :bragi_item, status: :unplayed, user: user, position: 0
        item.after_id = other_item.id
        item.save!
        expect(item.position).to eq 10
      end
    end

    describe '.resort' do
      it 'reorders items with stepped gaps' do
        item1 = create :bragi_item, status: :unplayed, user: user, position: 0
        item2 = create :bragi_item, status: :unplayed, user: user, position: 1
        item3 = create :bragi_item, status: :unplayed, user: user, position: 2
        item4 = create :bragi_item, status: :unplayed, user: user, position: 3
        Bragi::Item.resort(user.id)
        item1.reload
        item2.reload
        item3.reload
        item4.reload
        expect(item1.position).to eq 0
        expect(item2.position).to eq 10
        expect(item3.position).to eq 20
        expect(item4.position).to eq 30
      end
    end
  end
end
