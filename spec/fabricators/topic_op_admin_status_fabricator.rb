# frozen_string_literal: true

Fabricator(:topic_op_admin_status, from: UserAutonomyModule::TopicOpAdminStatus) do
  id
  can_close false
  can_archive false
  can_make_PM false
  can_visible false
  can_slow_mode false
  can_set_timer false
  can_silence false
  can_fold_posts false
  is_default false
end
