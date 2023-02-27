import { withPluginApi } from "discourse/lib/plugin-api";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import Topic from "discourse/models/topic";
import showModal from "discourse/lib/show-modal";
import TopicTimer from "discourse/models/topic-timer";
import I18n from "I18n";
import Composer from "discourse/models/composer";
// import DiscourseURL from "discourse/lib/url";
// import { getOwner } from "discourse-common/lib/get-owner";
// import { avatarFor } from "discourse/widgets/post";
// import ComponentConnector from "discourse/widgets/component-connector";
// import RawHtml from "discourse/widgets/raw-html";
// import { createWidget } from "discourse/widgets/widget";
// import { actionDescriptionHtml } from "discourse/widgets/post-small-action";
// import { h } from "virtual-dom";
// import { iconNode } from "discourse-common/lib/icon-library";
// import discourseLater from "discourse-common/lib/later";
// import { relativeAge } from "discourse/lib/formatter";
// import renderTags from "discourse/lib/render-tags";
// import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

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
    update(topicId, time, basedOnLastPost, statusType, categoryId, durationMinutes) {
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

  api.attachWidgetAction("topic-OP-admin-menu", "set-OP-admin-status", function () {
    const dialog = this.register.lookup("service:dialog");
    const topic = this.attrs.topic;
    showModal("set-topic-op-admin-status", {
      model: {
        topic,
        currentUser,
        action: {
          submit() {
            if (this.loading) {
              return;
            }
            this.setProperties({ loading: true });
            ajax("/topic_op_admin/set_topic_op_admin_status", {
              method: "POST",
              data: {
                id: topic.id,
                new_status: this.model.enables,
              },
            })
              .then((res) => {
                this.setProperties({ loading: false });
                this.send("closeModal");
                if (!res.success) {
                  dialog.alert(res.message);
                } else {
                  window.location.reload();
                }
              })
              .catch(popupAjaxError);
          },
        },
        enables: {
          close: topic.topic_op_admin_status.can_close,
          archive: topic.topic_op_admin_status.can_archive,
          make_PM: topic.topic_op_admin_status.can_make_PM,
          visible: topic.topic_op_admin_status.can_visible,
          slow_mode: topic.topic_op_admin_status.can_slow_mode,
          set_timer: topic.topic_op_admin_status.can_set_timer,
          silence: topic.topic_op_admin_status.can_silence,
          fold_posts: topic.topic_op_admin_status.can_fold_posts,
        },
      },
    });
  });
  api.attachWidgetAction("topic-OP-admin-menu", "apply-for-op-admin", function () {
    const composerController = this.register.lookup("controller:composer");
    const dialog = this.register.lookup("service:dialog");
    const topic = this.attrs.topic;
    const textTemplate =
      I18n.t("topic_op_admin.apply_modal.apply_template").replaceAll("#", `[${topic.title}](${topic.url})`) +
      `\n${I18n.t("topic_op_admin.apply_modal.apply_reason")}\n`;
    showModal("request-op-admin-form", {
      loading: false,
      model: {
        submit() {
          if (this.loading) {
            return;
          }
          this.setProperties({ loading: true });
          ajax("/topic_op_admin/request_for_topic_op_admin", {
            method: "POST",
            data: {
              id: topic.id,
              raw: textTemplate + this.reason,
            },
          })
            .then((res) => {
              this.setProperties({ loading: false });
              this.send("closeModal");
              dialog.alert(res.message);
            })
            .catch(popupAjaxError);
        },
        showComposer() {
          this.send("closeModal");
          composerController.open({
            action: Composer.PRIVATE_MESSAGE,
            draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
            recipients: currentUser.op_admin_form_recipients,
            topicTitle: I18n.t("topic_op_admin.apply_modal.apply_template_title").replaceAll("#", topic.title),
            topicBody: textTemplate,
            archetypeId: "private_message",
          });
        },
      },
    });
  });

  /**
   * send Ajax for topic-OP-admin-buttons, which often requires reason and model
   * @param {string} url string url
   * @param {string | "PUT" | "POST"} method string the method you need
   * @param {object} data ajax data
   * @param {object} helper helper
   * @param {string | undefined} reason text of your reason
   * @param {modal | undefined} modal modal if you have
   */
  function sendTopicOPAdminButtonAjax(url, method, data, helper, reason, modal) {
    const topic = helper.register.lookup("controller:topic");
    const dialog = helper.register.lookup("service:dialog");
    reason = reason || I18n.t("topic_op_admin.default_reason");
    data.id = helper.attrs.topic.id;
    data.reason = reason;
    ajax(url, {
      method,
      data,
    })
      .then((res) => {
        if (modal) {
          modal.setProperties({ loading: false });
          modal.send("closeModal");
        }
        if (!res.success) {
          dialog.alert(res.message);
        } else {
          // For ToggleOPAction like closed or archived
          if (data.status) {
            topic.model.toggleProperty(data.status);
          }
        }
      })
      .catch(popupAjaxError);
  }

  function sendToggleOPActionAjax(helper, status, reason, model) {
    sendTopicOPAdminButtonAjax(
      "/topic_op_admin/update_topic_status/",
      "POST",
      {
        status,
        enabled: !helper.attrs.topic[status],
      },
      helper,
      reason,
      model
    );
  }

  function sendTopicConvertAjax(helper, status, reason, model) {
    sendTopicOPAdminButtonAjax(
      "/topic_op_admin/topic_op_convert_topic",
      "PUT",
      {
        type: status,
      },
      helper,
      reason,
      model
    );
  }

  function toggleTopicOPAdminButton(helper, status, func) {
    const dialog = helper.register.lookup("service:dialog");
    if (currentUser.siteSettings.topic_op_admin_require_reason_before_action) {
      showModal("reason-before-topic-op-action-form", {
        model: {
          submit() {
            if (this.reason === "") {
              dialog.alert(I18n.t("topic_op_admin.reason_modal.alert_no_reason"));
            } else {
              if (this.loading) {
                return;
              }
              this.setProperties({ loading: true });
              func(helper, status, this.reason, this);
            }
          },
        },
      });
    } else {
      func(helper, status);
    }
  }

  function toggleOPAction(helper, status) {
    toggleTopicOPAdminButton(helper, status, sendToggleOPActionAjax);
  }

  api.attachWidgetAction("topic-OP-admin-menu", "topicOPtoggleClose", function () {
    toggleOPAction(this, "closed");
  });
  api.attachWidgetAction("topic-OP-admin-menu", "topicOPtoggleVisibility", function () {
    toggleOPAction(this, "visible");
  });
  api.attachWidgetAction("topic-OP-admin-menu", "topicOPtoggleArchived", function () {
    toggleOPAction(this, "archived");
  });
  api.attachWidgetAction("topic-OP-admin-menu", "topicOPShowTopicTimerModal", function () {
    this.register.lookup("controller:topic").send("showTopicTimerModal");
  });
  api.attachWidgetAction("topic-OP-admin-menu", "topicOPShowTopicSlowModeUpdate", function () {
    this.register.lookup("controller:topic").send("showTopicSlowModeUpdate");
  });
  api.attachWidgetAction("topic-OP-admin-menu", "topicOPConvertToPrivateMessage", function () {
    toggleTopicOPAdminButton(this, "private", sendTopicConvertAjax);
  });
  api.attachWidgetAction("topic-OP-admin-menu", "topicOPBanUsers", function () {
    const dialog = this.register.lookup("service:dialog");
    const topic = this.attrs.topic;
    const modal = showModal("topic-op-admin-silence-user", {
      model: {
        submit() {
          if (this.new_ban_users.length === 0 && this.new_unmute_users.length === 0) {
            this.send("closeModal");
            return;
          }
          let seconds;
          if (this.silence_time !== "") {
            seconds = Number(this.silence_time) * 60;
          } else {
            seconds = null;
          }
          if (this.reason === "") {
            dialog.alert(I18n.t("topic_op_admin.reason_modal.alert_no_reason"));
          } else {
            if (this.submitting) {
              return;
            }
            this.setProperties({ submitting: true });
            ajax("/topic_op_admin/update_topic_op_banned_users", {
              method: "PUT",
              data: {
                id: topic.id,
                new_silence_users: this.new_ban_users,
                seconds,
                new_unmute_users: this.new_unmute_users,
                reason: this.reason,
              },
            })
              .then((res) => {
                modal.setProperties({ submitting: false });
                modal.send("closeModal");
                if (!res.success) {
                  dialog.alert(res.message);
                }
              })
              .catch(popupAjaxError);
          }
        },
      },
    });
    modal.setProperties({
      submitting: false,
      new_ban_users: [],
      new_unmute_users: [],
      loading: true,
    });
    ajax("/topic_op_admin/get_topic_op_banned_users", {
      method: "GET",
      data: {
        id: this.attrs.topic.id,
      },
    })
      .then((res) => {
        modal.setProperties({
          loading: false,
          users: res.users,
        });
      })
      .catch(popupAjaxError);
  });
  api.decorateWidget("topic-admin-menu-button:after", (helper) => {
    const { openUpwards, topic } = helper.attrs;
    if (currentUser) {
      return helper.attach("topic-OP-admin-menu-button", {
        topic,
        addKeyboardTargetClass: false,
        openDownwards: !openUpwards,
        currentUser,
      });
    }
  });
}

export default {
  name: pluginId,

  initialize(container) {
    if (!container.lookup("site-settings:main").topic_op_admin_enabled) {
      return;
    }
    withPluginApi("1.6.0", init);
  },
};
