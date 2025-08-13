# frozen_string_literal: true

# name: user-autonomy-plugin
# about: Give topic's op some admin function
# version: 0.1.1
# authors: Lhc_fl
# url: https://github.com/Lemon-planting-light/user-autonomy-plugin
# required_version: 3.0.0

enabled_site_setting :user_autonomy_plugin_enabled

register_asset "stylesheets/user-autonomy-plugin.scss"
if respond_to?(:register_svg_icon)
  register_svg_icon "gear"
  register_svg_icon "gears"
  register_svg_icon "envelope-open-text"
end

module ::UserAutonomyModule
  PLUGIN_NAME = "user-autonomy-plugin"
end

require_relative "lib/user_autonomy_module/engine"

after_initialize do
  on(:post_created) do |*params|
    return unless SiteSetting.topic_op_admin_enabled

    post, _opt, user = params

    if UserAutonomyModule::TopicOpBannedUser.isBanned?(post.topic_id, user.id)
      if SiteSetting.topic_op_admin_delete_post_instead_of_hide?
        PostDestroyer.new(Discourse.system_user, post).destroy
      else
        post.hide!(1, custom_message: "silenced_by_topic_OP")
      end
    end
  end

  add_to_class(:user, :can_manipulate_topic_op_adminable?) do
    return true if admin?
    in_any_groups?(SiteSetting.topic_op_admin_manipulatable_groups_map)
  end
  add_to_serializer(:current_user, :can_manipulate_topic_op_adminable?) do
    user.can_manipulate_topic_op_adminable?
  end
  add_to_serializer(:current_user, :op_admin_form_recipients?) do
    SiteSetting.topic_op_admin_manipulatable_groups_map.map { |id| Group.find_by(id:).name }
  end
  add_to_class(:guardian, :can_manipulate_topic_op_adminable?) do
    user.can_manipulate_topic_op_adminable?
  end

  add_to_class(:topic, :topic_op_admin_status?) do
    UserAutonomyModule::TopicOpAdminStatus.getRecord?(id)
  end
  add_to_serializer(:topic_view, :topic_op_admin_status) do
    UserAutonomyModule::TopicOpAdminStatusSerializer.new(topic.topic_op_admin_status?).as_json[
      :topic_op_admin_status
    ]
  end

  add_to_class(:guardian, :can_close_topic_as_op?) do |topic|
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_close && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_archive_topic_as_op?) do |topic|
    return false if topic.archetype == Archetype.private_message
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_archive && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_unlist_topic_as_op?) do |topic|
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_visible && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_set_topic_slowmode_as_op?) do |topic|
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_slow_mode && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_set_topic_timer_as_op?) do |topic|
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_set_timer && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_make_PM_as_op?) do |topic|
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_make_PM && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_edit_topic_banned_user_list?) do |topic|
    return true if user.admin? || user.moderator?
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_silence && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_fold_post_as_op?) do |topic|
    return false unless SiteSetting.user_autonomy_plugin_enabled
    return false if user.silenced_till
    topic.topic_op_admin_status?.can_fold_posts && user.id == topic.user_id
  end
end
