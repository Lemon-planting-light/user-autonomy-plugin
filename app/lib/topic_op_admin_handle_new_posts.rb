# frozen_string_literal: true

DiscourseEvent.on(:post_created) do |*params|
  post, opt, user = params

  if TopicOpBannedUser.isBanned?(post.topic_id, user.id)
    if SiteSetting.topic_op_admin_delete_post_instead_of_hide?
      PostDestroyer.new(Discourse.system_user, post).destroy
    else
      post.hide!(1, custom_message: "silenced_by_topic_OP")
    end
  end

  # TODO: 开发Bot命令版本

  # bot = TopicOpUserAdminBot.getBot()

  # TopicOpUserAdminBot.botParseCmd(
  #   post.raw,
  #   {
  #     "@#{bot.username}" => ->(cmd) do
  #       guardian = Guardian.new(user)

  #       topic = BotLoggingTopic.find_by(id: post.topic_id)

  #       handles = {
  #         "silence" => ->(cmdlist) do
  #           target_user_at, seconds, *reasons = cmdlist.split(" ")

  #           puts "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n----------------------"
  #           puts reasons
  #           puts "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n----------------------"

  #           reasons = reasons.join(" ")

  #           puts reasons
  #           puts "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n----------------------"

  #           if seconds.to_i == 0
  #             reasons = (seconds || "") + " " + reasons
  #             seconds = nil
  #           else
  #             seconds = seconds.to_i * 60
  #           end

  #           guardian.ensure_can_see_topic!(topic)

  #           unless guardian.can_edit_topic_banned_user_list?(topic)
  #             TopicOpUserAdminBot.botSendPost(
  #               topic.id,
  #               I18n.t("topic_op_admin.no_perm"),
  #               reply_to_post_number: post.post_number,
  #             )
  #             return
  #           end

  #           target_user = User.find_by(username: target_user_at[1..])

  #           if target_user.nil? || target_user.admin? || target_user.moderator?
  #             TopicOpUserAdminBot.botSendPost(
  #               topic.id,
  #               I18n.t("topic_op_admin.bot_send_template.ban.failed"),
  #               reply_to_post_number: post.post_number,
  #             )
  #             return
  #           end

  #           TopicOpBannedUser.banUser(topic.id, target_user.id, seconds)

  #           if seconds.nil?
  #             TopicOpUserAdminBot.botSendPost(
  #               topic.id,
  #               I18n.t("topic_op_admin.bot_send_template.ban.success.forever") +
  #                 " @#{target_user.username}\n\n" + I18n.t("topic_op_admin.log_template.reason") +
  #                 " #{reasons}",
  #               reply_to_post_number: post.post_number,
  #             )
  #           else
  #             TopicOpUserAdminBot.botSendPost(
  #               topic.id,
  #               I18n.t("topic_op_admin.bot_send_template.ban.success.temp") +
  #                 " @#{target_user.username} #{seconds / 60}" +
  #                 I18n.t("topic_op_admin.bot_send_template.ban.success.min") + "\n\n" +
  #                 I18n.t("topic_op_admin.log_template.reason") + " #{reasons}",
  #               reply_to_post_number: post.post_number,
  #             )
  #           end
  #         end,
  #         "unmute" => ->(cmdlist) do
  #           target_user_at, *reasons = cmdlist.split " "

  #           reasons = reasons.join(" ")

  #           unless guardian.can_edit_topic_banned_user_list?(topic)
  #             TopicOpUserAdminBot.botSendPost(
  #               topic.id,
  #               I18n.t("topic_op_admin.no_perm"),
  #               reply_to_post_number: post.post_number,
  #             )
  #             return
  #           end

  #           target_user = User.find_by(username: target_user_at[1..])

  #           if target_user.nil?
  #             TopicOpUserAdminBot.botSendPost(
  #               topic.id,
  #               I18n.t("topic_op_admin.bot_send_template.unmute.failed"),
  #               reply_to_post_number: post.post_number,
  #             )
  #             return
  #           end

  #           TopicOpBannedUser.cancelBanUser(topic.id, target_user.id)

  #           TopicOpUserAdminBot.botSendPost(
  #             topic.id,
  #             I18n.t("topic_op_admin.bot_send_template.unmute.success") +
  #               " @#{target_user.username}\n\n" + I18n.t("topic_op_admin.log_template.reason") +
  #               " #{reasons}",
  #             reply_to_post_number: post.post_number,
  #           )
  #         end,
  #         "help" => ->(cmdlist) do
  #           TopicOpUserAdminBot.botSendPost(
  #             topic.id,
  #             "你好鸭， @#{user.username}\n\n我是用户自治bot。目前我仅支持以下命令（reason是理由）：\n\n@#{bot.username} silence `@xxx` minutes reason: 将xxx禁言minutes分钟\n@#{bot.username} unmute `@xxx` reason: 将xxx取消禁言",
  #             reply_to_post_number: post.post_number,
  #           )
  #         end,
  #       }

  #       TopicOpUserAdminBot.botParseCmd(cmd, handles)
  #     end,
  #   },
  # ) if user.id != bot.id
end
