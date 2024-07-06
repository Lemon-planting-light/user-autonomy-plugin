import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EditSlowModeModal from "discourse/components/modal/edit-slow-mode";
import EditTopicTimerModal from "discourse/components/modal/edit-topic-timer";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import RequestTopicOpAdminForm from "./modal/request-op-admin-form";
import SetTopicOpAdminStatusModal from "./modal/set-topic-op-admin-status";
import TellReasonForm from "./modal/tell-reason-form";
import TopicOpAdminSilenceUserModal from "./modal/topic-op-admin-silence-user-modal";

export default class TopicOpAdminMenuButton extends Component {
  @service currentUser;
  @service siteSettings;
  @service dialog;
  @service modal;

  @tracked updateTrigger = 1;

  get topic() {
    return this.args.outletArgs?.model ?? this.args.outletArgs?.topic;
  }

  get showButton() {
    return this.buttonList.length > 0;
  }

  get buttonListGrouped() {
    /** @type {Record<string, ButtonItem>} */
    const groups = {};
    for (const btn of this.buttonList) {
      const key = btn.group || "";
      groups[key] ??= [];
      groups[key].push(btn);
    }
    const res = [];
    for (const key of Object.keys(groups)) {
      res.push(...groups[key]);
      res.push(null);
    }
    res.pop();
    return res;
  }

  get buttonList() {
    (function () {})(this.updateTrigger); // Trigger
    /**
     * @typedef {{ label: string, icon: string, class: string, action: ()=>void, group?: string}} ButtonItem
     */
    /** @type {ButtonItem[]} */
    const res = [];

    if (
      this.currentUser == null ||
      this.topic == null ||
      this.topic.isPrivateMessage ||
      !this.currentUser.can_create_topic
    ) {
      return [];
    }

    if (this.currentUser.can_manipulate_topic_op_adminable) {
      res.push({
        action: this.showSetTopicOpAdminStatus,
        class: "topic-OP-admin-enable-topic-op-admin",
        icon: "cogs",
        label: "topic_op_admin.enable_topic_op_admin",
        group: "manipulating",
      });
    }

    if (this.topic.user_id === this.currentUser.id) {
      // Admin actions
      res.push({
        action: this.applyForTopicOpAdmin,
        class: "topic-OP-admin-apply-for-op-admin",
        icon: "envelope-open-text",
        label: "topic_op_admin.apply_for_op_admin",
        group: "manipulating",
      });
      if (this.topic.topic_op_admin_status.can_close) {
        res.push({
          group: "topic",
          action: () => this.performToggle("closed"),
          ...(this.topic.closed
            ? {
                class: "topic-OP-admin-open",
                icon: "unlock",
                label: "topic.actions.open",
              }
            : {
                class: "topic-OP-admin-close",
                icon: "lock",
                label: "topic.actions.close",
              }),
        });
      }
      if (this.topic.topic_op_admin_status.can_archive) {
        if (!this.topic.isPrivateMessage) {
          res.push({
            class: "topic-OP-admin-archive",
            action: () => this.performToggle("archived"),
            icon: this.topic.archived ? "folder-open" : "folder",
            label: this.topic.archived
              ? "topic.actions.unarchive"
              : "topic.actions.archive",
            group: "topic",
          });
        }
      }
      if (this.topic.topic_op_admin_status.can_visible) {
        res.push({
          class: "topic-OP-admin-visible",
          action: () => this.performToggle("visible"),
          icon: this.topic.visible ? "far-eye-slash" : "far-eye",
          label: this.topic.visible
            ? "topic.actions.invisible"
            : "topic.actions.visible",
          group: "topic",
        });
      }
      if (this.topic.topic_op_admin_status.can_slow_mode) {
        res.push({
          class: "topic-OP-admin-slow-mode",
          action: this.showTopicSlowModeUpdate,
          icon: "hourglass-start",
          label: "topic.actions.slow_mode",
          group: "time",
        });
      }

      if (this.topic.topic_op_admin_status.can_set_timer) {
        res.push({
          class: "admin-topic-timer-update",
          action: this.showTopicTimerModal,
          icon: "far-clock",
          label: "topic.actions.timed_update",
          group: "time",
        });
      }

      if (this.topic.topic_op_admin_status.can_make_PM) {
        res.push({
          class: "topic-admin-convert",
          action: this.topic.isPrivateMessage
            ? "topicOPConvertToPublicTopic" // TODO: convert to Public
            : () => this.performToggle("private"),
          icon: this.topic.isPrivateMessage ? "comment" : "envelope",
          label: this.topic.isPrivateMessage
            ? "topic.actions.make_public"
            : "topic.actions.make_private",
          group: "staff",
        });
      }
    }

    if (
      (this.topic.user_id === this.currentUser.id &&
        this.topic.topic_op_admin_status.can_silence) ||
      this.currentUser.staff
    ) {
      res.push({
        action: this.showTopicOpBanUsersForm,
        class: "topic-OP-admin-silence-user",
        icon: "microphone-slash",
        label: "topic_op_admin.silence_user",
        group: "staff",
      });
    }

    return res;
  }

  @action
  showSetTopicOpAdminStatus() {
    const topic = this.topic;
    this.modal.show(SetTopicOpAdminStatusModal, {
      model: {
        topic,
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
        cb: (modal) => {
          const new_status = {};
          for (const key of Object.keys(this.topic.topic_op_admin_status)) {
            // "can_open" -> "open"
            new_status[key] = modal.enables[key.slice(4)];
          }
          this.topic.set("topic_op_admin_status", new_status);
          this.updateTrigger = 1;
        },
      },
    });
  }

  /**
   * @param {string} url
   * @param {"POST" | "PUT"} method
   * @param {object} data
   * @param {?string} reason
   * @returns {Promise<void>}
   */
  _send_ajax(url, method, data, reason) {
    data.id = this.topic.id;
    reason ||= I18n.t("topic_op_admin.default_reason");
    data.reason = reason;
    return ajax(url, {
      method,
      data,
    })
      .then((res) => {
        if (!res.success) {
          this.dialog.alert(res.message);
        } else {
          if (data.status) {
            this.topic.toggleProperty(data.status);
          }
        }
      })
      .catch(popupAjaxError);
  }

  toggleTopicStatus(key, reason) {
    return this._send_ajax(
      "/topic_op_admin/update_topic_status/",
      "POST",
      {
        status: key,
        enabled: !this.topic.get(key),
      },
      reason
    );
  }

  convertTopic(type, reason) {
    return this._send_ajax(
      "/topic_op_admin/topic_op_convert_topic",
      "PUT",
      {
        type,
      },
      reason
    );
  }

  /** @param {String} name  */
  performToggle(name) {
    const name2handler = {
      closed: "toggleTopicStatus",
      visible: "toggleTopicStatus",
      archived: "toggleTopicStatus",
      private: "convertTopic",
    };
    const fn = this[name2handler[name]].bind(this);
    if (this.siteSettings.topic_op_admin_require_reason_before_action) {
      this.modal.show(TellReasonForm, {
        model: {
          submit: async (modal) => {
            if (modal.reason === "") {
              this.dialog.alert(
                I18n.t("topic_op_admin.reason_modal.alert_no_reason")
              );
            } else {
              await fn(name, modal.reason);
            }
          },
        },
      });
    } else {
      fn(name);
    }
  }

  @action
  showTopicSlowModeUpdate() {
    this.modal.show(EditSlowModeModal, {
      model: { topic: this.topic },
    });
  }

  @action
  showTopicTimerModal() {
    this.modal.show(EditTopicTimerModal, {
      model: {
        topic: this.topic,
        setTopicTimer: (v) => this.topic.set("topic_timer", v),
        updateTopicTimerProperty: this.updateTopicTimerProperty,
      },
    });
  }

  @action
  updateTopicTimerProperty(property, value) {
    this.topic.set(`topic_timer.${property}`, value);
  }

  @action
  applyForTopicOpAdmin() {
    this.modal.show(RequestTopicOpAdminForm, {
      model: {
        topic: this.topic,
      },
    });
  }

  @action
  showTopicOpBanUsersForm() {
    this.modal.show(TopicOpAdminSilenceUserModal, {
      model: {
        topic: this.topic,
      },
    });
  }
}
