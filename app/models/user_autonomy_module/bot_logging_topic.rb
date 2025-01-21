# frozen_string_literal: true

module UserAutonomyModule
  class BotLoggingTopic < ::Topic
    def add_moderator_post(user, text, opts = nil)
      opts ||= {}
      new_post = nil
      creator =
        PostCreator.new(
          user,
          raw: text,
          post_type: opts[:post_type] || Post.types[:moderator_action],
          action_code: opts[:action_code],
          no_bump: opts[:bump].blank?,
          topic_id: self.id,
          silent: opts[:silent],
          skip_validations: true,
          custom_fields: opts[:custom_fields],
          import_mode: opts[:import_mode],
          guardian: Guardian.new(Discourse.system_user),
        )

      if (new_post = creator.create) && new_post.present?
        increment!(:moderator_posts_count) if new_post.persisted?
        # If we are moving posts, we want to insert the moderator post where the previous posts were
        # in the stream, not at the end.
        if opts[:post_number].present?
          new_post.update!(post_number: opts[:post_number], sort_order: opts[:post_number])
        end

        # Grab any links that are present
        TopicLink.extract_from(new_post)
        QuotedPost.extract_from(new_post)
      end

      new_post
    end
  end
end
