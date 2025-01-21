# frozen_string_literal: true

::UserAutonomyModule::Engine.routes.draw do
  post "/update_topic_status" => "topic_op_admin#update_topic_status"
  put "/update_slow_mode" => "topic_op_admin#update_slow_mode"
  post "/set_topic_op_admin_status" => "topic_op_admin#set_topic_op_admin_status"
  post "/request_for_topic_op_admin" => "topic_op_admin#request_for_topic_op_admin"
  post "/set_topic_op_timer" => "topic_op_admin#set_topic_op_timer"
  put "/topic_op_convert_topic" => "topic_op_admin#topic_op_convert_topic"
  get "/get_topic_op_banned_users" => "topic_op_admin#get_topic_op_banned_users"
  put "/update_topic_op_banned_users" => "topic_op_admin#update_topic_op_banned_users"
end

Discourse::Application.routes.draw { mount ::UserAutonomyModule::Engine, at: "/topic_op_admin" }
