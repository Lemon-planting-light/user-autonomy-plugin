# frozen_string_literal: false

module ::UserAutonomyModule
  class TopicOpAdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    def update_topic_status
      params.require(:status)
      params.require(:enabled)
      params.permit(:until)

      topic = BotLoggingTopic.find_by({ id: params[:id] })
      status = params[:status]
      enabled = params[:enabled] == "true"
      params[:until] === "" ? params[:until] = nil : params[:until]
      params[:reason] = nil if params[:reason] == ""

      guardian.ensure_can_see_topic!(topic)

      generate_with_perm_logger_text =
        begin
          enable_text = enabled ? ".enable" : ".disable"
          "@#{current_user.username} " +
            I18n.t("topic_op_admin.log_template.with_perm.#{status}.#{enable_text}").gsub(
              "#",
              topic.url,
            ) + "\n#{I18n.t("topic_op_admin.log_template.reason")} #{params[:reason]}"
        end

      puts generate_with_perm_logger_text

      case status
      when "closed"
        guardian.ensure_can_close_topic_as_op!(topic)
      when "visible"
        guardian.ensure_can_unlist_topic_as_op!(topic)
      when "archived"
        guardian.ensure_can_archive_topic_as_op!(topic)
      else
        return render_fail "topic_op_admin.no_perm", status: 403
      end

      ::UserAutonomyModule::Bot.botLogger(generate_with_perm_logger_text)

      topic.update_status(
        status,
        enabled,
        current_user,
        until: params[:until],
        message: params[:reason] || I18n.t("topic_op_admin.reason_placeholder"),
      )

      render json:
               success_json.merge!(
                 topic_status_update:
                   TopicTimerSerializer.new(TopicTimer.find_by(topic: topic), root: false),
               )
    end

    def update_slow_mode
      params.require(:id)

      topic = Topic.find(params[:id])
      slow_mode_type = TopicTimer.types[:clear_slow_mode]
      timer = TopicTimer.find_by(topic: topic, status_type: slow_mode_type)

      guardian.ensure_can_see_topic!(topic)
      guardian.ensure_can_set_topic_slowmode_as_op!(topic)

      enabled = params[:seconds].to_i > 0
      time = enabled && params[:enabled_until].present? ? params[:enabled_until] : nil

      ::UserAutonomyModule::Bot.botLogger(
        "@#{current_user.username} " +
          I18n.t(
            "topic_op_admin.log_template.with_perm.slow_mode." + (enabled ? "enable" : "disable"),
          ).gsub("#", topic.url) + "\n```\n#{params.to_yaml}\n```",
      )

      topic.update!(slow_mode_seconds: params[:seconds])
      topic.set_or_create_timer(slow_mode_type, time, by_user: timer&.user)

      head :ok
    end

    def set_topic_op_admin_status
      params.require(:id)

      guardian.ensure_can_manipulate_topic_op_adminable!

      permissions = normal_permissions
      permissions += staff_permissions if current_user.staff?
      args = params.permit(:id, permissions).merge(is_default: false)
      topic = Topic.find_by(id: params[:id])

      ::UserAutonomyModule::Bot.botLogger(
        "@#{current_user.username} " +
          I18n.t("topic_op_admin.log_template.with_perm.set_admin_status").gsub("#", topic.url) +
          "\n```\n#{args.to_yaml}\n```",
      )

      status = TopicOpAdminStatus.create_or_update!(args)

      ::MessageBus.publish "/user-autonomy/topic/#{params[:id]}",
                           TopicOpAdminStatusSerializer.new(status).as_json

      head :ok
    end

    def request_for
      params.require(:id)
      params.require(:raw)

      topic = Topic.find(params[:id])

      unless current_user.id == topic.user.id
        raise Discourse::InvalidAccess.new "not the topic owner"
      end

      ::UserAutonomyModule::Bot.botLogger(
        "@#{current_user.username} " + I18n.t("topic_op_admin.apply_title").gsub("#", topic.url) +
          ":\n[quote=\"#{current_user.username}\"]\n#{params[:raw]}\n[/quote]",
      )

      post =
        PostCreator.create!(
          current_user,
          title: I18n.t("topic_op_admin.apply_title").gsub("#", topic.title),
          raw: params[:raw],
          archetype: Archetype.private_message,
          target_group_names:
            Group.where(id: SiteSetting.topic_op_admin_manipulatable_groups_map).pluck(:name),
          skip_validations: true,
        )

      unless topic.topic_op_admin_status&.is_not_default?
        auto_allowed =
          all_permissions.select do |perm|
            SiteSetting.send("topic_op_admin_tags_autogrant_#{perm}_map").intersect?(
              topic.tags.pluck(:name),
            )
          end

        if SiteSetting.topic_op_admin_basic_autoallowing_tags_map.intersect?(
             topic.tags.pluck(:name),
           ) ||
             SiteSetting
               .topic_op_admin_basic_autoallowing_categories
               .split("|")
               .include?(topic.category&.id.to_s)
          auto_allowed += SiteSetting.topic_op_admin_basic_list_map
        end

        if auto_allowed.present?
          PostCreator.create!(
            Discourse.system_user,
            topic_id: post.topic_id,
            raw: I18n.t("topic_op_admin.autoallowing_request"),
            skip_validations: true,
          )

          status =
            TopicOpAdminStatus.create_or_update!(
              id: topic.id,
              is_default: true,
              **auto_allowed.map { |perm| [perm.to_s, true] }.to_h,
            )

          ::MessageBus.publish "/user-autonomy/topic/#{params[:id]}",
                               TopicOpAdminStatusSerializer.new(status).as_json
        end
      end

      render json: success_json.merge!(message: I18n.t("topic_op_admin.get_request"))
    end

    def set_topic_op_timer
      params.permit(:time, :based_on_last_post, :category_id)
      params.require(:status_type)

      status_type =
        begin
          TopicTimer.types.fetch(params[:status_type].to_sym)
        rescue StandardError
          invalid_param(:status_type)
        end
      based_on_last_post = params[:based_on_last_post]
      params.require(:duration_minutes) if based_on_last_post

      topic = Topic.find_by(id: params[:id])

      if !guardian.can_set_topic_timer_as_op?(topic) ||
           TopicTimer.destructive_types.values.include?(status_type)
        ::UserAutonomyModule::Bot.botLogger(
          "@#{current_user.username} " +
            I18n.t("topic_op_admin.log_template.without_perm.set_timer").gsub("#", topic.url) +
            "\n```\n#{params.to_yaml}\n```",
        )
        return render_fail "topic_op_admin.no_perm", status: 403
      end

      options = { by_user: current_user, based_on_last_post: based_on_last_post }

      options.merge!(category_id: params[:category_id]) if !params[:category_id].blank?
      if params[:duration_minutes].present?
        options.merge!(duration_minutes: params[:duration_minutes].to_i)
      end
      options.merge!(duration: params[:duration].to_i) if params[:duration].present?

      begin
        topic_timer = topic.set_or_create_timer(status_type, params[:time], **options)
      rescue ActiveRecord::RecordInvalid => e
        return render_json_error(e.message)
      end

      ::UserAutonomyModule::Bot.botLogger(
        "@#{current_user.username} " +
          I18n.t("topic_op_admin.log_template.with_perm.set_timer").gsub("#", topic.url) +
          "\n```\n#{params.to_yaml}\n```",
      )

      if topic.save
        render json:
                 success_json.merge!(
                   execute_at: topic_timer&.execute_at,
                   duration_minutes: topic_timer&.duration_minutes,
                   based_on_last_post: topic_timer&.based_on_last_post,
                   closed: topic.closed,
                   category_id: topic_timer&.category_id,
                 )
      else
        render_json_error(topic)
      end
    end

    def topic_op_convert_topic
      params.require(:id)
      params.require(:type)
      params.require(:reason)
      topic = BotLoggingTopic.find_by(id: params[:id])

      unless guardian.can_make_PM_as_op?(topic)
        ::UserAutonomyModule::Bot.botLogger(
          "@#{current_user.username} " +
            I18n.t("topic_op_admin.log_template.without_perm.make_PM.enable").gsub("#", topic.url) +
            "\n```\n#{params.to_yaml}\n```",
        )
        return render_fail "topic_op_admin.no_perm", status: 403
      end

      if params[:type] == "public"
        ::UserAutonomyModule::Bot.botLogger(
          "@#{current_user.username} " +
            I18n.t("topic_op_admin.log_template.without_perm.make_PM.disable").gsub(
              "#",
              topic.url,
            ) + "\n```\n#{params.to_yaml}\n```",
        )
        return render_fail "topic_op_admin.no_perm", status: 403
      else
        converted_topic = topic.convert_to_private_message(current_user)
        ::UserAutonomyModule::Bot.botLogger(
          "@#{current_user.username} " +
            I18n.t("topic_op_admin.log_template.with_perm.make_PM.enable").gsub("#", topic.url) +
            "\n#{I18n.t("topic_op_admin.log_template.reason")} #{params[:reason]}",
        )
      end

      to_revise_post = Post.find_by(topic_id: topic.id, post_number: topic.highest_post_number + 1)

      # 修订帖子
      if to_revise_post.raw == "" && to_revise_post.user_id == current_user.id
        PostRevisor.new(to_revise_post, topic).revise!(current_user, { raw: params[:reason] }, {})
      else
        PostCreator.create(current_user, topic_id: topic.id, raw: params[:reason])
      end

      render_topic_changes(converted_topic)
    end

    def render_fail(*args, **kwargs)
      response.status = kwargs[:status] || 400
      render json: { success: false, message: I18n.t(*args, **kwargs.except(:status)) }
      nil
    end

    def get_topic_op_banned_users
      params.require(:id)

      users = []

      TopicOpBannedUser
        .where(topic_id: params[:id])
        .each do |record|
          user = User.find_by(id: record.user_id)
          if user.admin? || user.moderator? ||
               user.in_any_groups?(SiteSetting.topic_op_admin_never_be_banned_groups_map)
            next
          end
          if record.banned_seconds.nil? || Time.now <= record.banned_at + record.banned_seconds
            u = JSON.parse(BasicUserSerializer.new(user, root: false).to_json)
            u["banned_at"] = record.banned_at
            u["banned_seconds"] = record.banned_seconds
            users.push(u)
          end
        end

      render json: { success: true, users: }
    end

    def update_topic_op_banned_users
      params.require(:id)
      params.permit(:new_silence_users)
      params.permit(:new_unmute_users)
      params.require(:reason)

      params[:new_silence_users] ||= []
      params[:new_unmute_users] ||= []

      seconds = params[:seconds].to_i
      seconds = nil if seconds == 0

      # We don't want any one to silence too many users
      if (params[:new_silence_users].length > 100)
        return render_fail "topic_op_admin.too_many", status: 403
      end

      topic = BotLoggingTopic.find_by(id: params[:id])

      guardian.ensure_can_see_topic!(topic)

      unless guardian.can_edit_topic_banned_user_list?(topic)
        ::UserAutonomyModule::Bot.botLogger(
          "@#{current_user.username} " +
            I18n.t("topic_op_admin.log_template.without_perm.silence").gsub("#", topic.url) +
            "\n```\n#{params.to_yaml}\n```",
        )
        return render_fail "topic_op_admin.no_perm", status: 403
      end

      ::UserAutonomyModule::Bot.botLogger(
        "@#{current_user.username} " +
          I18n.t("topic_op_admin.log_template.with_perm.silence").gsub("#", topic.url) +
          "\n```\n#{params.to_yaml}\n```",
      )

      unmute_names = ""
      mute_names = ""

      params[:new_unmute_users].each do |id|
        target_user = User.find_by(id:)
        unmute_names << "@#{target_user.username}, "
        TopicOpBannedUser.cancelBanUser(topic.id, id)
      end

      failed = false

      params[:new_silence_users].each do |username|
        target_user = User.find_by(username:)

        if target_user.nil? || target_user.admin? || target_user.moderator?
          failed = true
        else
          mute_names << "@#{username}, "
          TopicOpBannedUser.banUser(topic.id, target_user.id, seconds)
        end
      end

      silence_time =
        (
          if seconds.nil?
            I18n.t("topic_op_admin.bot_send_template.ban.forever")
          else
            "#{seconds.to_i / 60} " + I18n.t("topic_op_admin.bot_send_template.ban.success.min")
          end
        )

      unmute_line = ""
      unmute_line =
        I18n.t("topic_op_admin.bot_send_template.unmute.text") + ": " + unmute_names +
          "\n" if unmute_names != ""

      mute_line = ""
      mute_line =
        I18n.t("topic_op_admin.bot_send_template.ban.text") + ": " + mute_names + "\n" +
          I18n.t("topic_op_admin.bot_send_template.ban.time") + ": " + silence_time +
          "\n" if mute_names != ""

      if !(mute_line == "" && unmute_line == "")
        ::UserAutonomyModule::Bot.botSendPost(
          topic.id,
          "@#{current_user.username}\n\n" + unmute_line + mute_line +
            I18n.t("topic_op_admin.log_template.reason") + " #{params[:reason]}",
          skip_validations: true,
        )
      end

      if failed
        render_fail "topic_op_admin.succeed_partial", status: 403
      else
        render json: { success: true }
      end
    end

    def render_topic_changes(dest_topic)
      if dest_topic.present?
        render json: { success: true, url: dest_topic.relative_url }
      else
        render json: { success: false }
      end
    end

    private

    def normal_permissions
      %i[can_close can_archive can_visible can_slow_mode can_set_timer can_fold_posts]
    end

    def staff_permissions
      %i[can_make_PM can_silence]
    end

    def all_permissions
      normal_permissions + staff_permissions
    end
  end
end
