# frozen_string_literal: true

require_relative "../lib/bot.rb"

class TopicOpAdminController < ::ApplicationController
  before_action :ensure_logged_in

  def get_user()
    SiteSetting.topic_op_admin_bot_override_user? ? TopicOpUserAdminBot.getBot() : guardian.user
  end

  def update_topic_status
    unless SiteSetting.topic_op_admin_enabled
      return render_fail "topic_op_admin.not_enabled", status: 405
    end

    params.require(:status)
    params.require(:enabled)
    params.permit(:until)

    topic = BotLoggingTopic.find_by({ id: params[:id] })
    status = params[:status]
    topic_id = params[:topic_id].to_i
    enabled = params[:enabled] == "true"
    params[:until] === "" ? params[:until] = nil : params[:until]
    params[:reason] = nil if params[:reason] == ""

    guardian.ensure_can_see_topic!(topic)

    generate_with_perm_logger_text =
      begin
        enable_text = enabled ? ".enable" : ".disable"
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.with_perm.#{status}.#{enable_text}").gsub(
            "#",
            topic.url,
          ) + "\n#{I18n.t("topic_op_admin.log_template.reason")} #{params[:reason]}"
      end

    generate_without_perm_logger_text =
      begin
        enable_text = enabled ? ".enable" : ".disable"
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.without_perm.#{status}.#{enable_text}").gsub(
            "#",
            topic.url,
          ) + "\n#{I18n.t("topic_op_admin.log_template.reason")} #{params[:reason]}"
      end

    puts generate_with_perm_logger_text

    case status
    when "closed"
      unless guardian.can_close_topic_as_op?(topic)
        TopicOpUserAdminBot.botLogger(generate_without_perm_logger_text)
        return render_fail "topic_op_admin.no_perm", status: 403
      end
    when "visible"
      unless guardian.can_unlist_topic_as_op?(topic)
        TopicOpUserAdminBot.botLogger(generate_without_perm_logger_text)
        return render_fail "topic_op_admin.no_perm", status: 403
      end
    when "archived"
      unless guardian.can_archive_topic_as_op?(topic)
        TopicOpUserAdminBot.botLogger(generate_without_perm_logger_text)
        return render_fail "topic_op_admin.no_perm", status: 403
      end
    else
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.without_perm.otherwise").gsub("#", topic.url) +
          "\n```\n#{params.to_yaml}\n```",
      )
      return render_fail "topic_op_admin.no_perm", status: 403
    end

    TopicOpUserAdminBot.botLogger(generate_with_perm_logger_text)

    topic.update_status(
      status,
      enabled,
      get_user,
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
    unless SiteSetting.topic_op_admin_enabled
      return render_fail "topic_op_admin.not_enabled", status: 405
    end

    params.require(:id)

    topic = Topic.find(params[:id])
    slow_mode_type = TopicTimer.types[:clear_slow_mode]
    timer = TopicTimer.find_by(topic: topic, status_type: slow_mode_type)

    guardian.ensure_can_see_topic!(topic)

    enabled = params[:seconds].to_i > 0
    time = enabled && params[:enabled_until].present? ? params[:enabled_until] : nil

    unless guardian.can_set_topic_slowmode_as_op?(topic)
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
          I18n.t(
            "topic_op_admin.log_template.without_perm.slow_mode." +
              (enabled ? "enable" : "disable"),
          ).gsub("#", topic.url) + "\n```\n#{params.to_yaml}\n```",
      )
      return render_fail "topic_op_admin.no_perm", status: 403
    end

    TopicOpUserAdminBot.botLogger(
      "@#{guardian.user.username} " +
        I18n.t(
          "topic_op_admin.log_template.with_perm.slow_mode." + (enabled ? "enable" : "disable"),
        ).gsub("#", topic.url) + "\n```\n#{params.to_yaml}\n```",
    )

    topic.update!(slow_mode_seconds: params[:seconds])
    topic.set_or_create_timer(slow_mode_type, time, by_user: timer&.user)

    head :ok
  end

  def set_topic_op_admin_status
    unless SiteSetting.topic_op_admin_enabled
      return render_fail "topic_op_admin.not_enabled", status: 405
    end

    params.require(:id)
    params.require(:new_status)

    topic = Topic.find(params[:id])

    unless guardian.can_manipulate_topic_op_adminable?
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.without_perm.set_admin_status").gsub("#", topic.url) +
          "\n```\n#{params[:new_status].to_yaml}\n```",
      )
      return render_fail "topic_op_admin.no_perm", status: 403
    end

    ns = {
      can_close: params[:new_status]["close"],
      can_archive: params[:new_status]["archive"],
      can_make_PM: params[:new_status]["make_PM"],
      can_visible: params[:new_status]["visible"],
      can_slow_mode: params[:new_status]["slow_mode"],
      can_set_timer: params[:new_status]["set_timer"],
      can_silence: params[:new_status]["silence"],
      can_fold_posts: params[:new_status]["fold_posts"],
    }

    TopicOpUserAdminBot.botLogger(
      "@#{guardian.user.username} " +
        I18n.t("topic_op_admin.log_template.with_perm.set_admin_status").gsub("#", topic.url) +
        "\n```\n#{params[:new_status].to_yaml}\n```",
    )

    TopicOpAdminStatus.updateRecord(params[:id], **ns)

    render json: success_json.merge!(topic_op_admin_status_update: params[:new_status])
  end

  def request_for_topic_op_admin
    # TODO: request_for_topic_op_admin private message
    unless SiteSetting.topic_op_admin_enabled
      return render_fail "topic_op_admin.not_enabled", status: 405
    end

    params.require(:id)
    params.require(:raw)

    topic = Topic.find(params[:id])

    TopicOpUserAdminBot.botLogger(
      "@#{guardian.user.username} " + I18n.t("topic_op_admin.apply_title").gsub("#", topic.url) +
        ":\n[quote=\"#{guardian.user.username}\"]\n#{params[:raw]}\n[/quote]",
    )

    post =
      PostCreator.create!(
        guardian.user,
        title: I18n.t("topic_op_admin.apply_title").gsub("#", topic.title),
        raw: params[:raw],
        archetype: Archetype.private_message,
        target_group_names:
          SiteSetting.topic_op_admin_manipulatable_groups_map.map { |id| Group.find_by(id:).name },
        skip_validations: true,
      )

    if topic.topic_op_admin_status?.is_default
      ns = {}
      ds = {}

      if SiteSetting
           .topic_op_admin_basic_autoallowing_tags
           .to_s
           .split("|")
           .intersect?(topic.tags.map(&:name)) ||
           SiteSetting
             .topic_op_admin_basic_autoallowing_categories
             .to_s
             .split("|")
             .map(&:to_i)
             .include?(topic.category&.id)
        SiteSetting.topic_op_admin_basic_list.split("|").each { |i| ds[i] = true }
      end

      %w[
        can_close
        can_visible
        can_make_PM
        can_archive
        can_set_timer
        can_silence
        can_slow_mode
      ].each do |status|
        if SiteSetting
             .method("topic_op_admin_tags_autogrant_#{status}")
             .call()
             .to_s
             .split("|")
             .intersect?(topic.tags.map(&:name))
          ds[status] = true
        end
      end

      ns = {
        can_close: ds["can_close"] || false,
        can_archive: ds["can_archive"] || false,
        can_make_PM: ds["can_make_PM"] || false,
        can_visible: ds["can_visible"] || false,
        can_slow_mode: ds["can_slow_mode"] || false,
        can_set_timer: ds["can_set_timer"] || false,
        can_silence: ds["can_silence"] || false,
        can_fold_posts: ds["can_fold_posts"] || false,
      }

      PostCreator.create!(
        Discourse.system_user,
        topic_id: post.topic_id,
        raw: I18n.t("topic_op_admin.autoallowing_request"),
        skip_validations: true,
      )

      TopicOpAdminStatus.updateRecord(topic.id, **ns)
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
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
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

    TopicOpUserAdminBot.botLogger(
      "@#{guardian.user.username} " +
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
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.without_perm.make_PM.enable").gsub("#", topic.url) +
          "\n```\n#{params.to_yaml}\n```",
      )
      return render_fail "topic_op_admin.no_perm", status: 403
    end

    if params[:type] == "public"
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.without_perm.make_PM.disable").gsub("#", topic.url) +
          "\n```\n#{params.to_yaml}\n```",
      )
      return render_fail "topic_op_admin.no_perm", status: 403
    else
      converted_topic = topic.convert_to_private_message(get_user)
      TopicOpUserAdminBot.botLogger(
        "@#{guardian.user.username} " +
          I18n.t("topic_op_admin.log_template.with_perm.make_PM.enable").gsub("#", topic.url) +
          "\n#{I18n.t("topic_op_admin.log_template.reason")} #{params[:reason]}",
      )
    end

    to_revise_post = Post.find_by(topic_id: topic.id, post_number: topic.highest_post_number + 1)

    # 修订帖子
    if to_revise_post.raw == "" && to_revise_post.user_id == get_user.id
      PostRevisor.new(to_revise_post, topic).revise!(get_user, { raw: params[:reason] }, {})
    else
      PostCreator.create(get_user, topic_id: topic.id, raw: params[:reason])
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

    TopicOpbannedUsers
      .where(topic_id: params[id:])
      .each do |record|
        user = User.find_by(id: record.user_id)
        if user.admin? || user.moderator? ||
             user.in_any_groups?(SiteSetting.topic_op_admin_never_be_banned_groups_map)
          return false
        end
        return true if record.banned_seconds.nil?
        if Time.now <= record.banned_at + record.banned_seconds
          users.push(BasicUserSerializer.new(user, root: false))
        end
      end

    render json: { success: true, users: }
  end

  def render_topic_changes(dest_topic)
    if dest_topic.present?
      render json: { success: true, url: dest_topic.relative_url }
    else
      render json: { success: false }
    end
  end
end
