# frozen_string_literal: true

# name: user-autonomy-plugin
# about: Give topic's op some admin function
# version: 0.3.0
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
  reloadable_patch do
    Topic.prepend UserAutonomyModule::TopicMixin
    Guardian.prepend UserAutonomyModule::GuardianMixin
  end

  add_to_serializer(:current_user, :can_manipulate_topic_op_adminable?) do
    scope.can_manipulate_topic_op_adminable?
  end
  add_to_serializer(:current_user, :op_admin_form_recipients?) do
    SiteSetting.topic_op_admin_manipulatable_groups_map.map { |id| Group.find_by(id:).name }
  end

  add_to_serializer(:topic_view, :topic_op_admin_status) do
    UserAutonomyModule::TopicOpAdminStatusSerializer.new(
      object.topic.topic_op_admin_status,
    ).as_json(root: false)
  end
end
