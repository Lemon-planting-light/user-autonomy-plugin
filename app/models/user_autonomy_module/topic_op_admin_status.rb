# frozen_string_literal: true

module UserAutonomyModule
  class TopicOpAdminStatus < ::ActiveRecord::Base
    self.table_name = "topic_op_admin_status"

    def is_not_default?
      !is_default
    end

    def self.create_or_update!(params)
      old = self.find_by(id: params[:id])
      if old.present?
        old.update!(is_default: false, **params)
        old
      else
        self.create!(params)
      end
    end
  end
end

# == Schema Information
#
# Table name: topic_op_admin_status
#
#  id             :bigint           not null, primary key
#  can_close      :boolean          default(FALSE)
#  can_archive    :boolean          default(FALSE)
#  can_make_PM    :boolean          default(FALSE)
#  can_visible    :boolean          default(FALSE)
#  can_slow_mode  :boolean          default(FALSE)
#  can_set_timer  :boolean          default(FALSE)
#  can_silence    :boolean          default(FALSE)
#  can_fold_posts :boolean          default(FALSE)
#  is_default     :boolean          default(TRUE), not null
#
