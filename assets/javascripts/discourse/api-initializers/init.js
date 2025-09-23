import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { bind } from "discourse/lib/decorators";
import Topic from "discourse/models/topic";
import TopicTimer from "discourse/models/topic-timer";
import TopicOpAdminMenuButton from "../components/topic-op-admin-menu-button";

export default apiInitializer((api) => {
  if (!api.container.lookup("service:site-settings").topic_op_admin_enabled) {
    return;
  }

  const currentUser = api.getCurrentUser();

  if (!currentUser) {
    return;
  }

  api.modifyClass(
    "controller:topic",
    (Superclass) =>
      class extends Superclass {
        subscribe() {
          super.subscribe(...arguments);
          this.messageBus.subscribe(
            `/user-autonomy/topic/${this.model.id}`,
            this._onPostFoldingMessage
          );
        }

        unsubscribe() {
          this.messageBus.unsubscribe(
            "/discourse-post-folding/topic/*",
            this._onPostFoldingMessage
          );
          super.unsubscribe(...arguments);
        }

        @bind
        _onPostFoldingMessage(msg) {
          // console.log("received", msg);
          // console.log(this.model);
          this.set("model.topic_op_admin_status", msg.topic_op_admin_status);
          this.appEvents.trigger("user-autonomy:changed");
        }
      }
  );

  Topic.reopenClass({
    setSlowMode(topicId, seconds, enabledUntil) {
      const data = { seconds };
      data.enabled_until = enabledUntil;
      if (currentUser.canManageTopic) {
        // Discourse default ajax
        return ajax(`/t/${topicId}/slow_mode`, { type: "PUT", data });
      } else {
        data.id = topicId;
        return ajax("/topic-op-admin/update_slow_mode", { type: "PUT", data });
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
          url: `/topic-op-admin/set_topic_op_timer`,
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
});
