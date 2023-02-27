# frozen_string_literal: true

module TopicOpUserAdminBot
  # def TopicOpUserAdminBot.create_bot(id, admin: false, username: nil)
  #   User.new.tap do |user|
  #     user.id = id
  #     user.email = "user#{SecureRandom.hex}@localhost#{SecureRandom.hex}.fake"
  #     user.username = username || "user#{SecureRandom.hex}"
  #     user.password = SecureRandom.hex
  #     user.username_lower = user.username.downcase
  #     user.active = true
  #     user.approved = true
  #     user.save!
  #     user.grant_admin! if admin
  #     user.change_trust_level!(TrustLevel[4])
  #     user.activate
  #   end
  # end

  def TopicOpUserAdminBot.getBot()
    User.find_by(id: SiteSetting.topic_op_admin_bot_user_id?) || Discourse.system_user
  end

  def TopicOpUserAdminBot.botLogger(rawText)
    if SiteSetting.topic_op_admin_enable_topic_log?
      PostCreator.create!(
        getBot,
        topic_id: SiteSetting.topic_op_admin_logger_topic?,
        raw: rawText,
        guardian: Guardian.new(Discourse.system_user),
        import_mode: true,
      )
    end
  end

  def TopicOpUserAdminBot.botSendPost(topic_id, rawText, **opts)
    PostCreator.create!(
      getBot,
      topic_id: topic_id,
      raw: rawText,
      guardian: Guardian.new(Discourse.system_user),
      **opts,
    )
  end

  def TopicOpUserAdminBot.botParseCmd(text, handles)
    return nil if text.length > 100
    text = text.strip
    slice_p = text.index " "
    handles[text[...slice_p]]&.call(text[slice_p..].lstrip)
  end
end
