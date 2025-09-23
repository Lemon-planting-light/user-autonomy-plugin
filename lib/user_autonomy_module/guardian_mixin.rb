# frozen_string_literal: true

module UserAutonomyModule
  module GuardianMixin
    extend ActiveSupport::Concern

    prepended do
      def can_create_post_on_topic?(topic)
        # No users can create posts on deleted topics
        return false if topic.blank?
        return false if topic.trashed?
        return true if is_admin?

        return false if UserAutonomyModule::TopicOpBannedUser.isBanned?(topic.id, user.id)

        trusted =
          (authenticated? && user.has_trust_level?(TrustLevel[4])) || is_moderator? ||
            can_perform_action_available_to_group_moderators?(topic)

        (!(topic.closed? || topic.archived?) || trusted) && can_create_post?(topic)
      end

      def can_close_topic_as_op?(topic)
        return false if is_silenced?
        topic.topic_op_admin_status&.can_close && user.id == topic.user_id
      end

      def can_archive_topic_as_op?(topic)
        return false if topic.archetype == Archetype.private_message
        return false if is_silenced?
        topic.topic_op_admin_status&.can_archive && user.id == topic.user_id
      end

      def can_unlist_topic_as_op?(topic)
        return false if is_silenced?
        topic.topic_op_admin_status&.can_visible && user.id == topic.user_id
      end

      def can_set_topic_slowmode_as_op?(topic)
        return false if is_silenced?
        topic.topic_op_admin_status&.can_slow_mode && user.id == topic.user_id
      end

      def can_set_topic_timer_as_op?(topic)
        return false if is_silenced?
        topic.topic_op_admin_status&.can_set_timer && user.id == topic.user_id
      end

      def can_make_PM_as_op?(topic)
        return false if is_silenced?
        topic.topic_op_admin_status&.can_make_PM && user.id == topic.user_id
      end

      def can_edit_topic_banned_user_list?(topic)
        return true if user.staff?
        return false if is_silenced?
        topic.topic_op_admin_status&.can_silence && user.id == topic.user_id
      end

      def can_fold_post_as_op?(topic)
        return false unless SiteSetting.user_autonomy_plugin_enabled
        return false if is_silenced?
        topic.topic_op_admin_status&.can_fold_posts && user.id == topic.user_id
      end

      def can_manipulate_topic_op_adminable?
        return true if is_admin?
        user.in_any_groups?(SiteSetting.topic_op_admin_manipulatable_groups_map)
      end
    end
  end
end
