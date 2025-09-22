# frozen_string_literal: true

module UserAutonomyModule
  module TopicMixin
    extend ActiveSupport::Concern

    prepended do
      has_one :topic_op_admin_status,
              class_name: "UserAutonomyModule::TopicOpAdminStatus",
              foreign_key: "id"
    end
  end
end
