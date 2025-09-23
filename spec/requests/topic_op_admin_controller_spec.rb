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

  fab!(:tag1) { Fabricate(:tag) }
  fab!(:tag2) { Fabricate(:tag) }

  fab!(:topic) { Fabricate(:topic, tags: [tag1, tag2]) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  NORMAL_PERMISSIONS = %i[
    can_close
    can_archive
    can_visible
    can_slow_mode
    can_set_timer
    can_fold_posts
  ]

  STAFF_PERMISSIONS = %i[can_make_PM can_silence]

  ALL_PERMISSIONS = NORMAL_PERMISSIONS + STAFF_PERMISSIONS

  describe "#set_topic_op_admin_status" do
    context "when user is not authorized" do
      before { sign_in(user) }

      it "cannot set topic_op_admin_status for a topic" do
        expect(topic.topic_op_admin_status).to be_nil
        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: ALL_PERMISSIONS.map { |perm| [perm, true] }.to_h

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
             params: ALL_PERMISSIONS.map { |perm| [perm, true] }.to_h

        expect(response.status).to eq(200)

        topic.reload
        ALL_PERMISSIONS.each { |perm| expect(topic.topic_op_admin_status.send(perm)).to eq(true) }
      end
    end

    context "when user is in allowed group" do
      before { sign_in(allowed_user) }

      it "can set topic_op_admin_status for a topic, but not staff params" do
        expect(topic.topic_op_admin_status).to be_nil

        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: ALL_PERMISSIONS.map { |perm| [perm, true] }.to_h
        expect(response.status).to eq(200)

        topic.reload
        NORMAL_PERMISSIONS.each do |perm|
          expect(topic.topic_op_admin_status.send(perm)).to eq(true)
        end
        STAFF_PERMISSIONS.each do |perm|
          expect(topic.topic_op_admin_status.send(perm)).to eq(false)
        end
      end

      it "won't affect existing topic_op_admin_status's staff params" do
        Fabricate(
          :topic_op_admin_status,
          id: topic.id,
          **ALL_PERMISSIONS.map { |perm| [perm, true] }.to_h,
        )

        post "/topic-op-admin/set-topic-op-admin-status/#{topic.id}.json",
             params: ALL_PERMISSIONS.map { |perm| [perm, false] }.to_h

        NORMAL_PERMISSIONS.each do |perm|
          expect(topic.topic_op_admin_status.send(perm)).to eq(false)
        end
        STAFF_PERMISSIONS.each { |perm| expect(topic.topic_op_admin_status.send(perm)).to eq(true) }
      end
    end
  end

  describe "#request_for" do
    context "when user is not the owner" do
      before { sign_in(user) }

      it "cannot create a request post" do
        post "/topic-op-admin/request-for/#{topic.id}.json",
             params: {
               raw: "Please change the topic status.",
             }
        expect(response.status).to eq(403)
        expect(topic.topic_op_admin_status).to be_nil
      end
    end

    context "when user is the owner" do
      before { sign_in(topic.user) }

      it "creates a request message to allowed_groups" do
        post "/topic-op-admin/request-for/#{topic.id}.json",
             params: {
               raw: "Please change the topic status.",
             }
        expect(response.status).to eq(200)

        last_topic = Topic.last
        expect(last_topic.user).to eq(topic.user)
        expect(last_topic.archetype).to eq(Archetype.private_message)
        expect(last_topic.first_post.raw).to eq("Please change the topic status.")
        expect(last_topic.allowed_users).to include(topic.user)
        expect(last_topic.allowed_groups.pluck(:id)).to match_array(
          SiteSetting.topic_op_admin_manipulatable_groups_map,
        )
        expect(topic.topic_op_admin_status).to be_nil
      end

      it "automatically grants base permissions based on tag" do
        SiteSetting.topic_op_admin_basic_autoallowing_tags = tag1.name

        post "/topic-op-admin/request-for/#{topic.id}.json",
             params: {
               raw: "Please change the topic status.",
             }
        expect(response.status).to eq(200)

        ALL_PERMISSIONS.each do |perm|
          if SiteSetting.topic_op_admin_basic_list_map.include?(perm.to_s)
            expect(topic.topic_op_admin_status.send(perm)).to eq(true)
          else
            expect(topic.topic_op_admin_status.send(perm)).to eq(false)
          end
        end
      end

      it "automatically grants base permissions based on category" do
        SiteSetting.topic_op_admin_basic_autoallowing_categories = topic.category.id.to_s

        post "/topic-op-admin/request-for/#{topic.id}.json",
             params: {
               raw: "Please change the topic status.",
             }
        expect(response.status).to eq(200)

        ALL_PERMISSIONS.each do |perm|
          if SiteSetting.topic_op_admin_basic_list_map.include?(perm.to_s)
            expect(topic.topic_op_admin_status.send(perm)).to eq(true)
          else
            expect(topic.topic_op_admin_status.send(perm)).to eq(false)
          end
        end
      end

      5.times do
        random_perms = ALL_PERMISSIONS.sample(3)

        it "automatically grants permissions based on tag - tries #{random_perms}" do
          random_perms.each do |perm|
            SiteSetting.send(
              "topic_op_admin_tags_autogrant_#{perm}=",
              [tag1.name, tag2.name].sample,
            )
          end

          post "/topic-op-admin/request-for/#{topic.id}.json",
               params: {
                 raw: "Please change the topic status.",
               }
          expect(response.status).to eq(200)

          random_perms.each { |perm| expect(topic.topic_op_admin_status.send(perm)).to eq(true) }
          (ALL_PERMISSIONS - random_perms).each do |perm|
            expect(topic.topic_op_admin_status.send(perm)).to eq(false)
          end
        end
      end
    end
  end
end
