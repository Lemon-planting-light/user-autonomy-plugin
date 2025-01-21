# frozen_string_literal: true

class TopicOpBannedUser < ActiveRecord::Base
  self.table_name = "topic_op_banned_user"

  def self.isBanned?(topic_id, user_id)
    user = User.find_by(id: user_id)
    if user.admin? || user.moderator? ||
         user.in_any_groups?(SiteSetting.topic_op_admin_never_be_banned_groups_map)
      return false
    end
    data = self.find_by(topic_id:, user_id:)
    return false if data.nil?
    return true if data.banned_seconds.nil?
    Time.now <= data.banned_at + data.banned_seconds
  end

  def self.banUser(topic_id, user_id, seconds = nil)
    if self.exists?(topic_id:, user_id:)
      self.find_by(topic_id:, user_id:).update!(banned_at: Time.now, banned_seconds: seconds)
    else
      self.create(topic_id:, user_id:, banned_seconds: seconds, banned_at: Time.now)
    end
  end

  def self.cancelBanUser(topic_id, user_id)
    self.destroy_by(topic_id:, user_id:) if self.exists?(topic_id:, user_id:)
  end
end

# == Schema Information
#
# Table name: topic_op_banned_user
#
#  id             :bigint           not null, primary key
#  topic_id       :integer
#  user_id        :integer
#  banned_at      :datetime         not null
#  banned_seconds :integer
#
