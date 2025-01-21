# frozen_string_literal: true

class TopicOpAdminStatus < ActiveRecord::Base
  self.table_name = "topic_op_admin_status"

  def self.getRecord?(id)
    ret = self.find_by(id:)
    self.updateRecord(id) unless ret
    ret = self.find_by(id:)
  end

  def self.updateRecord(id, **new_status)
    if self.exists?(id:)
      self.find_by(id:).update!(is_default: false, **new_status)
    else
      self.create(id: id, **new_status)
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
