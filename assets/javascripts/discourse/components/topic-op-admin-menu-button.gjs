import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import EditSlowModeModal from "discourse/components/modal/edit-slow-mode";
import EditTopicTimerModal from "discourse/components/modal/edit-topic-timer";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import RequestTopicOpAdminForm from "./modal/request-op-admin-form";
import SetTopicOpAdminStatusModal from "./modal/set-topic-op-admin-status";
import TellReasonForm from "./modal/tell-reason-form";
import TopicOpAdminSilenceUserModal from "./modal/topic-op-admin-silence-user-modal";

export default class TopicOpAdminMenuButton extends Component {
  static shouldRender(attrs, { currentUser }) {
    if (currentUser == null || !currentUser.can_create_topic) {
      return false;
    }
    const topic = attrs.topic ?? attrs.model;
    if (topic == null || topic.isPrivateMessage) {
      return false;
    }
    return true;
  }

  @service currentUser;
  @service siteSettings;
  @service dialog;
  @service modal;
  @service appEvents;

  @tracked trick = 1;

  constructor() {
    super(...arguments);
    this.appEvents.on("user-autonomy:changed", this.onUserAutonomyChanged);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("user-autonomy:changed", this.onUserAutonomyChanged);
  }

  @bind
  onUserAutonomyChanged() {
    this.trick = this.trick + 1;
  }

  get topic() {
    return this.args.model ?? this.args.topic;
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
    /**
     * @typedef {{ label: string, icon: string, class: string, action: ()=>void, group?: string}} ButtonItem
     */
    /** @type {ButtonItem[]} */
    const res = [];

    // trick
    if (this.trick === 0) {
      return;
    }

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
        icon: "gears",
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
      if (this.topic.topic_op_admin_status?.can_close) {
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
      if (this.topic.topic_op_admin_status?.can_archive) {
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
      if (this.topic.topic_op_admin_status?.can_visible) {
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
      if (this.topic.topic_op_admin_status?.can_slow_mode) {
        res.push({
          class: "topic-OP-admin-slow-mode",
          action: this.showTopicSlowModeUpdate,
          icon: "hourglass-start",
          label: "topic.actions.slow_mode",
          group: "time",
        });
      }

      if (this.topic.topic_op_admin_status?.can_set_timer) {
        res.push({
          class: "admin-topic-timer-update",
          action: this.showTopicTimerModal,
          icon: "far-clock",
          label: "topic.actions.timed_update",
          group: "time",
        });
      }

      if (this.topic.topic_op_admin_status?.can_make_PM) {
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
        this.topic.topic_op_admin_status?.can_silence) ||
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
    this.modal.show(SetTopicOpAdminStatusModal, {
      model: {
        topic: this.topic,
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
    reason ||= i18n("topic_op_admin.default_reason");
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
      "/topic-op-admin/update_topic_status/",
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
      "/topic-op-admin/topic_op_convert_topic",
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
                i18n("topic_op_admin.reason_modal.alert_no_reason")
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

  <template>
    {{#if this.showButton}}
      <span class="topic-OP-admin-menu-button-container">
        <span class="topic-OP-admin-menu-button">
          <DMenu
            @identifier="topic-OP-admin-menu"
            @modalForMobile={{true}}
            @autofocus={{true}}
            @triggerClass="btn-default btn-icon toggle-OP-admin-menu"
          >
            <:trigger>
              {{icon "gear"}}
            </:trigger>
            <:content>
              <DropdownMenu as |dropdown|>
                {{#each this.buttonListGrouped as |button|}}
                  {{#if button}}
                    <dropdown.item>
                      <DButton
                        @label={{button.label}}
                        @translatedLabel={{button.translatedLabel}}
                        @icon={{button.icon}}
                        class={{concatClass "btn-transparent" button.className}}
                        @action={{button.action}}
                      />
                    </dropdown.item>
                  {{else}}
                    <dropdown.divider />
                  {{/if}}
                {{/each}}
              </DropdownMenu>
            </:content>
          </DMenu>
        </span>
      </span>
    {{/if}}
  </template>
}
