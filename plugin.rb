# frozen_string_literal: true

# name: user-autonomy-plugin
# about: Give topic's op some admin function
# version: 0.1.1
# authors: Lhc_fl
# url: https://github.com/Lemon-planting-light/user-autonomy-plugin
# required_version: 3.0.0

enabled_site_setting :user_autonomy_plugin_enabled

register_asset "stylesheets/topic-op-admin.scss"
if respond_to?(:register_svg_icon)
  register_svg_icon "cog"
  register_svg_icon "cogs"
  register_svg_icon "envelope-open-text"
end

require_relative "app/lib/bot"

after_initialize do
  %w[
    app/controllers/topic_op_admin_controller
    app/models/topic_op_admin_status
    app/serializers/topic_op_admin_status_serializer
    app/models/bot_logging_topic
    app/lib/topic_op_admin_handle_new_posts
    app/models/topic_op_banned_user
  ].each { |f| require_relative File.expand_path("../#{f}", __FILE__) }

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

  add_to_class(:topic, :topic_op_admin_status?) { TopicOpAdminStatus.getRecord?(id) }
  add_to_serializer(:topic_view, :topic_op_admin_status) do
    TopicOpAdminStatusSerializer.new(topic.topic_op_admin_status?).as_json[:topic_op_admin_status]
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
end
