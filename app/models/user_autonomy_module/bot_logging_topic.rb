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

# == Schema Information
#
# Table name: topics
#
#  id                        :integer          not null, primary key
#  archetype                 :string           default("regular"), not null
#  archived                  :boolean          default(FALSE), not null
#  bannered_until            :datetime
#  bumped_at                 :datetime         not null
#  closed                    :boolean          default(FALSE), not null
#  deleted_at                :datetime
#  excerpt                   :string
#  fancy_title               :string
#  featured_link             :string
#  has_summary               :boolean          default(FALSE), not null
#  highest_post_number       :integer          default(0), not null
#  highest_staff_post_number :integer          default(0), not null
#  incoming_link_count       :integer          default(0), not null
#  last_posted_at            :datetime
#  like_count                :integer          default(0), not null
#  locale                    :string(20)
#  moderator_posts_count     :integer          default(0), not null
#  notify_moderators_count   :integer          default(0), not null
#  participant_count         :integer          default(1)
#  percent_rank              :float            default(1.0), not null
#  pinned_at                 :datetime
#  pinned_globally           :boolean          default(FALSE), not null
#  pinned_until              :datetime
#  posts_count               :integer          default(0), not null
#  reply_count               :integer          default(0), not null
#  reviewable_score          :float            default(0.0), not null
#  score                     :float
#  slow_mode_seconds         :integer          default(0), not null
#  slug                      :string
#  spam_count                :integer          default(0), not null
#  subtype                   :string
#  title                     :string           not null
#  views                     :integer          default(0), not null
#  visible                   :boolean          default(TRUE), not null
#  word_count                :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  category_id               :integer
#  deleted_by_id             :integer
#  external_id               :string
#  featured_user1_id         :integer
#  featured_user2_id         :integer
#  featured_user3_id         :integer
#  featured_user4_id         :integer
#  image_upload_id           :bigint
#  last_post_user_id         :integer          not null
#  user_id                   :integer
#  visibility_reason_id      :integer
#
# Indexes
#
#  idx_topics_front_page                   (deleted_at,visible,archetype,category_id,id)
#  idx_topics_user_id_deleted_at           (user_id) WHERE (deleted_at IS NULL)
#  idxtopicslug                            (slug) WHERE ((deleted_at IS NULL) AND (slug IS NOT NULL))
#  index_topics_on_bannered_until          (bannered_until) WHERE (bannered_until IS NOT NULL)
#  index_topics_on_bumped_at_public        (bumped_at) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text))
#  index_topics_on_created_at_and_visible  (created_at,visible) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text))
#  index_topics_on_external_id             (external_id) UNIQUE WHERE (external_id IS NOT NULL)
#  index_topics_on_id_and_deleted_at       (id,deleted_at)
#  index_topics_on_id_filtered_banner      (id) UNIQUE WHERE (((archetype)::text = 'banner'::text) AND (deleted_at IS NULL))
#  index_topics_on_image_upload_id         (image_upload_id)
#  index_topics_on_lower_title             (lower((title)::text))
#  index_topics_on_pinned_at               (pinned_at) WHERE (pinned_at IS NOT NULL)
#  index_topics_on_pinned_globally         (pinned_globally) WHERE pinned_globally
#  index_topics_on_pinned_until            (pinned_until) WHERE (pinned_until IS NOT NULL)
#  index_topics_on_timestamps_private      (bumped_at,created_at,updated_at) WHERE ((deleted_at IS NULL) AND ((archetype)::text = 'private_message'::text))
#  index_topics_on_updated_at_public       (updated_at,visible,highest_staff_post_number,highest_post_number,category_id,created_at,id) WHERE (((archetype)::text <> 'private_message'::text) AND (deleted_at IS NULL))
#
