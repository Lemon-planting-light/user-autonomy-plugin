# frozen_string_literal: true

module UserAutonomyModule
  class TopicOpAdminStatus < ::ActiveRecord::Base
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
end
