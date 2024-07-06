class TopicOpAdminStatusSerializer < ApplicationSerializer
  attributes :can_close,
             :can_archive,
             :can_make_PM,
             :can_visible,
             :can_slow_mode,
             :can_set_timer,
             :can_silence,
             :can_fold_posts,
             :is_default
end
