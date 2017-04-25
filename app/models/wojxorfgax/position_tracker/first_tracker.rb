# frozen_string_literal: true

module Wojxorfgax
  class PositionTracker
    class FirstTracker
      def initialize(item)
        @item = item
      end

      def position
        first_item = Wojxorfgax::Item.sorted(@item.wojxorfgax_user_id).first
        if first_item
          first_item.position - PositionTracker::POSITION_STEP
        else
          PositionTracker::FIRST_ITEM_POSITION
        end
      end
    end
  end
end
