import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import Topic from "discourse/models/topic";
import TopicTimer from "discourse/models/topic-timer";
import TopicOpAdminMenuButton from "../components/topic-op-admin-menu-button";

const pluginId = "topic-OP-admin";

function init(api) {
  const currentUser = api.getCurrentUser();

  if (!currentUser) {
    return;
  }

  Topic.reopenClass({
    setSlowMode(topicId, seconds, enabledUntil) {
      const data = { seconds };
      data.enabled_until = enabledUntil;
      if (currentUser.canManageTopic) {
        // Discourse default ajax
        return ajax(`/t/${topicId}/slow_mode`, { type: "PUT", data });
      } else {
        data.id = topicId;
        return ajax("/topic_op_admin/update_slow_mode", { type: "PUT", data });
      }
    },
  });
  TopicTimer.reopenClass({
    update(
      topicId,
      time,
      basedOnLastPost,
      statusType,
      categoryId,
      durationMinutes
    ) {
      let data = {
        time,
        status_type: statusType,
      };
      if (basedOnLastPost) {
        data.based_on_last_post = basedOnLastPost;
      }
      if (categoryId) {
        data.category_id = categoryId;
      }
      if (durationMinutes) {
        data.duration_minutes = durationMinutes;
      }
      if (currentUser.canManageTopic) {
        // Discourse default ajax
        return ajax({
          url: `/t/${topicId}/timer`,
          type: "POST",
          data,
        });
      } else {
        data.id = topicId;
        return ajax({
          url: `/topic_op_admin/set_topic_op_timer`,
          type: "POST",
          data,
        });
      }
    },
  });

  api.renderInOutlet("timeline-controls-before", TopicOpAdminMenuButton);
  api.renderInOutlet("before-topic-progress", TopicOpAdminMenuButton);
  // api.renderInOutlet(
  //   "topic-footer-main-buttons-before-create",
  //   TopicOpAdminMenuButton
  // );
}

export default {
  name: pluginId,

  initialize(container) {
    if (!container.lookup("service:site-settings").topic_op_admin_enabled) {
      return;
    }
    withPluginApi("1.8.0", init);
  },
};
