# frozen_string_literal: true
class AddTopicOpIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :topic_op_banned_user, %i[topic_id user_id], unique: true
    add_index :topic_op_banned_user, :topic_id
  end
end
