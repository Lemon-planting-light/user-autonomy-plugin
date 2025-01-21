# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostFolding::PostFoldingStatusController do
  before do
    SiteSetting.user_autonomy_plugin_enabled = true
    SiteSetting.discourse_post_folding_enabled = true
    SiteSetting.discourse_post_folding_can_fold_post_groups =
      "#{allowed_group.id}|#{staff_group.id}"
  end

  fab!(:staff_group) { Group.find_by(name: "staff") }
  fab!(:non_allowed_group) { Fabricate(:group) }
  fab!(:allowed_group) { Fabricate(:group) }

  fab!(:admin)
  fab!(:allowed_user) { Fabricate(:user, username: "mads", name: "Mads", groups: [allowed_group]) }
  fab!(:non_admin_staff) { Fabricate(:user, groups: [staff_group]) }
  fab!(:user_in_non_allowed_group) { Fabricate(:user, groups: [non_allowed_group]) }

  fab!(:topic) { Fabricate(:topic, user: user_in_non_allowed_group) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  context "when user is not from allowed groups" do
    it "still results 403" do
      sign_in(user_in_non_allowed_group)
      put "/discourse-post-folding/status/#{post_2.id}.json", params: {}
      expect(response.status).to eq(403)
      expect(response.parsed_body["message"]).to eq("no permisson")
      expect(DiscoursePostFolding::PostFoldingStatus.find_by(post_id: post_2.id).present?).to eq(
        false,
      )
      delete "/discourse-post-folding/status/#{post_2.id}.json", params: {}
      expect(response.status).to eq(403)
      expect(response.parsed_body["message"]).to eq("no permisson")
    end
  end

  context "when user is from allowed groups or user is an allowed topic op" do
    fab!(:op_relationship) { Fabricate(:topic_op_admin_status, can_fold_posts: true, id: topic.id) }

    shared_examples "login as user" do |user, type|
      it "allows when user is a #{type}" do
        sign_in(self.send(user))
        put "/discourse-post-folding/status/#{post_2.id}.json", params: {}
        expect(response.status).to eq(200)
        expect(DiscoursePostFolding::PostFoldingStatus.find_by(post_id: post_2.id).present?).to eq(
          true,
        )
        delete "/discourse-post-folding/status/#{post_2.id}.json", params: {}
        expect(response.status).to eq(200)
        expect(DiscoursePostFolding::PostFoldingStatus.find_by(post_id: post_2.id).present?).to eq(
          false,
        )
      end
    end

    include_examples "login as user", :admin, "admin"
    include_examples "login as user", :non_admin_staff, "non_admin_staff"
    include_examples "login as user", :allowed_user, "allowed_user"
    include_examples "login as user", :user_in_non_allowed_group, "op"

    it "still rejects when user try to fold op" do
      sign_in(admin)
      put "/discourse-post-folding/status/#{post_1.id}.json", params: {}
      expect(response.status).to eq(403)
      expect(response.parsed_body["message"]).to eq("cannot fold op")
      expect(DiscoursePostFolding::PostFoldingStatus.find_by(post_id: post_1.id).present?).to eq(
        false,
      )
    end
  end
end
