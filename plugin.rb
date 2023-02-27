# frozen_string_literal: true

# name: User-Autonomy-Plugin
# about: Give topic's op some admin function
# version: 0.0.1
# authors: Lhc_fl
# url: TODO
# required_version: 3.0.0

enabled_site_setting :user_autonomy_plugin_enabled

register_asset "stylesheets/topic-op-admin.scss"
if respond_to?(:register_svg_icon)
  register_svg_icon "cog"
  register_svg_icon "cogs"
  register_svg_icon "envelope-open-text"
end

require_relative "app/lib/bot.rb"

after_initialize do
  %w[
    app/controllers/topic_op_admin_controller.rb
    app/lib/bot.rb
    app/models/topic_op_admin_status.rb
    app/models/bot_logging_topic.rb
    app/lib/topic_op_admin_handle_new_posts.rb
    app/models/topic_op_banned_user.rb
  ].each { |f| load File.expand_path("../#{f}", __FILE__) }

  Discourse::Application.routes.append do
    post "/topic_op_admin/update_topic_status" => "topic_op_admin#update_topic_status"
    put "/topic_op_admin/update_slow_mode" => "topic_op_admin#update_slow_mode"
    post "/topic_op_admin/set_topic_op_admin_status" => "topic_op_admin#set_topic_op_admin_status"
    post "/topic_op_admin/request_for_topic_op_admin" => "topic_op_admin#request_for_topic_op_admin"
    post "/topic_op_admin/set_topic_op_timer" => "topic_op_admin#set_topic_op_timer"
    put "/topic_op_admin/topic_op_convert_topic" => "topic_op_admin#topic_op_convert_topic"
    get "/topic_op_admin/get_topic_op_banned_users" => "topic_op_admin#get_topic_op_banned_users"
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

  add_to_class(:topic, :topic_op_admin_status?) { TopicOpAdminStatus.getRecord?(id) }
  add_to_serializer(:topic_view, :topic_op_admin_status) { topic.topic_op_admin_status? }

  add_to_class(:guardian, :can_close_topic_as_op?) do |topic|
    topic.topic_op_admin_status?.can_close && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_archive_topic_as_op?) do |topic|
    return false if topic.archetype == Archetype.private_message
    topic.topic_op_admin_status?.can_archive && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_unlist_topic_as_op?) do |topic|
    topic.topic_op_admin_status?.can_visible && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_set_topic_slowmode_as_op?) do |topic|
    topic.topic_op_admin_status?.can_slow_mode && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_set_topic_timer_as_op?) do |topic|
    topic.topic_op_admin_status?.can_set_timer && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_make_PM_as_op?) do |topic|
    topic.topic_op_admin_status?.can_make_PM && user.id == topic.user_id
  end
  add_to_class(:guardian, :can_edit_topic_banned_user_list?) do |topic|
    return true if user.admin? || user.moderator?
    topic.topic_op_admin_status?.can_silence && user.id == topic.user_id
  end
end
