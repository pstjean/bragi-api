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

FactoryGirl.define do
  factory :bragi_item, class: 'Bragi::Item' do
    sequence(:audio_identifier) { |i| "01/01/01/blah#{i}" }
    sequence(:position) { |i| i }
    audio_url 'MyString'
    audio_title 'MyString'
    audio_description 'MyText'
    audio_hosts 'MyText'
    audio_program 'MyString'
    audio_publish_datetime '2017-01-01T00:00:00Z'
    audio_image_url 'https://example.com/test.jpg'
    origin_url 'MyString'
    source 'MyString'
    playtime 1
    status :unplayed
    finished nil
    user nil

    factory :bragi_played_item do
      position nil
      finished Time.zone.now
      status :played
    end
  end
end
