# frozen_string_literal: true

# == Schema Information
#
# Table name: bragi_users
#
#  id           :integer          not null, primary key
#  external_uid :string(255)      not null
#  secret_uid   :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

require 'rails_helper'

module Bragi
  RSpec.describe User, type: :model do
  end
end
