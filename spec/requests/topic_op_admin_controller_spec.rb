# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserAutonomyModule::TopicOpAdminController do
  before do
    SiteSetting.user_autonomy_plugin_enabled = true
    SiteSetting.discourse_post_folding_enabled = true
    SiteSetting.topic_op_admin_manipulatable_groups = "#{allowed_group.id}|#{staff_group.id}"
  end

  fab!(:staff_group) { Group.find_by(name: "staff") }
  fab!(:non_allowed_group) { Fabricate(:group) }
  fab!(:allowed_group) { Fabricate(:group) }

  fab!(:admin)
  fab!(:moderator)
  fab!(:allowed_user) { Fabricate(:user, username: "mads", name: "Mads", groups: [allowed_group]) }
  fab!(:user)

  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  describe "#set_topic_op_admin_status" do
    context "when user is not authorized" do
      before { sign_in(user) }

      it "cannot set topic_op_admin_status for a topic" do
        expect(topic.topic_op_admin_status).to be_nil

        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: {
               can_close: true,
               can_archive: true,
               can_make_PM: true,
               can_visible: true,
               can_slow_mode: true,
               can_set_timer: true,
               can_silence: true,
               can_fold_posts: true,
             }
        expect(response.status).to eq(403)

        topic.reload
        expect(topic.topic_op_admin_status).to be_nil
      end
    end

    context "when user is staff" do
      before { sign_in(moderator) }

      it "can set topic_op_admin_status for a topic" do
        expect(topic.topic_op_admin_status).to be_nil

        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: {
               can_close: true,
               can_archive: true,
               can_make_PM: true,
               can_visible: true,
               can_slow_mode: true,
               can_set_timer: true,
               can_silence: true,
               can_fold_posts: true,
             }
        expect(response.status).to eq(200)

        topic.reload
        expect(topic.topic_op_admin_status).to be_present
        expect(topic.topic_op_admin_status.can_close).to eq(true)
        expect(topic.topic_op_admin_status.can_archive).to eq(true)
        expect(topic.topic_op_admin_status.can_visible).to eq(true)
        expect(topic.topic_op_admin_status.can_slow_mode).to eq(true)
        expect(topic.topic_op_admin_status.can_set_timer).to eq(true)
        expect(topic.topic_op_admin_status.can_silence).to eq(true)
        expect(topic.topic_op_admin_status.can_make_PM).to eq(true)
        expect(topic.topic_op_admin_status.can_fold_posts).to eq(true)
        expect(topic.topic_op_admin_status.is_default).to eq(false)
      end
    end

    context "when user is in allowed group" do
      before { sign_in(allowed_user) }

      it "can set topic_op_admin_status for a topic, but not staff params" do
        expect(topic.topic_op_admin_status).to be_nil

        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: {
               can_close: true,
               can_archive: true,
               can_make_PM: true,
               can_visible: true,
               can_slow_mode: true,
               can_set_timer: true,
               can_silence: true,
               can_fold_posts: true,
             }
        expect(response.status).to eq(200)

        topic.reload
        expect(topic.topic_op_admin_status).to be_present
        expect(topic.topic_op_admin_status.can_close).to eq(true)
        expect(topic.topic_op_admin_status.can_archive).to eq(true)
        expect(topic.topic_op_admin_status.can_visible).to eq(true)
        expect(topic.topic_op_admin_status.can_slow_mode).to eq(true)
        expect(topic.topic_op_admin_status.can_set_timer).to eq(true)
        expect(topic.topic_op_admin_status.can_silence).to eq(false)
        expect(topic.topic_op_admin_status.can_make_PM).to eq(false)
        expect(topic.topic_op_admin_status.can_fold_posts).to eq(true)
      end

      it "won't affect existing topic_op_admin_status's staff params" do
        Fabricate(
          :topic_op_admin_status,
          id: topic.id,
          can_close: true,
          can_archive: true,
          can_make_PM: true,
          can_visible: true,
          can_slow_mode: true,
          can_set_timer: true,
          can_silence: true,
          can_fold_posts: true,
        )

        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: {
               can_close: false,
               can_archive: false,
               can_make_PM: false,
               can_visible: false,
               can_slow_mode: false,
               can_set_timer: false,
               can_silence: false,
               can_fold_posts: false,
             }

        expect(topic.topic_op_admin_status).to be_present
        expect(topic.topic_op_admin_status.can_close).to eq(false)
        expect(topic.topic_op_admin_status.can_archive).to eq(false)
        expect(topic.topic_op_admin_status.can_visible).to eq(false)
        expect(topic.topic_op_admin_status.can_slow_mode).to eq(false)
        expect(topic.topic_op_admin_status.can_set_timer).to eq(false)
        expect(topic.topic_op_admin_status.can_silence).to eq(true)
        expect(topic.topic_op_admin_status.can_make_PM).to eq(true)
        expect(topic.topic_op_admin_status.can_fold_posts).to eq(false)
      end
    end
  end
end
