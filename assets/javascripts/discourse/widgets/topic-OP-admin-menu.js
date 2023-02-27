/* eslint-disable no-unused-vars */
import { applyDecorators, createWidget, createWidgetFrom, queryRegistry } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import RawHtml from "discourse/widgets/raw-html";
import { iconHTML } from "discourse-common/lib/icon-library";
import getURL from "discourse-common/lib/get-url";
import { postUrl } from "discourse/lib/utilities";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

createWidget("OP-admin-menu-button", {
  tagName: "li",

  buildClasses(attrs) {
    return attrs.className;
  },

  html(attrs) {
    let className;
    if (attrs.buttonClass) {
      className = attrs.buttonClass;
    }

    return this.attach("button", {
      className,
      action: attrs.action,
      url: attrs.url,
      icon: attrs.icon,
      label: attrs.fullLabel || `topic.${attrs.label}`,
      secondaryAction: "hideTopicOPAdminMenu",
    });
  },
});

createWidget("topic-OP-admin-menu-button", {
  tagName: "span.topic-OP-admin-menu-button",
  buildKey: () => "topic-OP-admin-menu-button",

  defaultState() {
    return { expanded: false, position: null };
  },

  html(attrs, state) {
    const result = [];

    const menu = this.attach("topic-OP-admin-menu", {
      position: state.position,
      topic: attrs.topic,
      openDownwards: attrs.openDownwards,
      rightSide: !this.site.mobileView && attrs.rightSide,
      actionButtons: [],
    });

    // We don't show the button when expanded on the right side on desktop

    if (menu.attrs.actionButtons.length && (!(attrs.rightSide && state.expanded) || this.site.mobileView)) {
      result.push(
        this.attach("button", {
          className:
            "btn-default popup-menu-button toggle-admin-menu" +
            (attrs.addKeyboardTargetClass ? " keyboard-target-admin-menu" : ""),
          title: "topic_op_admin.menu_button_title",
          icon: "cog",
          action: "showTopicOPAdminMenu",
          sendActionEvent: true,
        })
      );
    }

    if (state.expanded) {
      result.push(menu);
    }

    return result;
  },

  hideTopicOPAdminMenu() {
    this.state.expanded = false;
    this.state.position = null;
  },

  showTopicOPAdminMenu(e) {
    this.state.expanded = true;
    let button;

    if (e === undefined) {
      button = document.querySelector(".keyboard-target-topic-OP-admin-menu");
    } else {
      button = e.target.closest("button");
    }

    const position = { top: button.offsetTop, left: button.offsetLeft };
    const spacing = 3;
    const menuWidth = 212;

    const rtl = document.documentElement.classList.contains("html.rtl");
    const buttonDOMRect = button.getBoundingClientRect();
    position.outerHeight = buttonDOMRect.height;

    if (!this.attrs.openDownwards) {
      if (rtl) {
        position.left -= buttonDOMRect.width + spacing;
      } else {
        position.left += buttonDOMRect.width + spacing;
      }
      position.top -= 20;
      if (position.left > window.innerWidth - menuWidth) {
        position.left = window.innerWidth - menuWidth - spacing;
      }
    } else {
      if (rtl) {
        if (buttonDOMRect.left < menuWidth) {
          position.left += 0;
        } else {
          position.left -= menuWidth - buttonDOMRect.width;
        }
      } else {
        const offsetRight = window.innerWidth - buttonDOMRect.right;

        if (offsetRight < menuWidth) {
          position.left -= menuWidth - buttonDOMRect.width;
        }
      }

      position.top += buttonDOMRect.height + spacing;
    }

    this.state.position = position;
  },

  didRenderWidget() {
    let menuButtons = document.querySelectorAll(".topic-OP-admin-popup-menu button");

    if (menuButtons && menuButtons[0]) {
      menuButtons[0].focus();
    }
  },

  topicToggleActions() {
    this.state.expanded ? this.hideTopicOPAdminMenu() : this.showTopicOPAdminMenu();
  },
});

export default createWidget("topic-OP-admin-menu", {
  tagName: "div.popup-menu.topic-admin-popup-menu.topic-OP-admin-popup-menu",

  buildClasses(attrs) {
    if (attrs.rightSide) {
      return "right-side";
    }
  },

  init(attrs) {
    const topic = attrs.topic;
    const details = topic.get("details");
    const isPrivateMessage = topic.get("isPrivateMessage");
    const visible = topic.get("visible");

    if (isPrivateMessage) {
      return;
    }

    if (this.get("currentUser.can_manipulate_topic_op_adminable")) {
      this.addActionButton({
        action: "set-OP-admin-status",
        className: "topic-OP-admin-enable-topic-op-admin",
        buttonClass: "popup-menu-btn",
        icon: "cogs",
        fullLabel: "topic_op_admin.enable_topic_op_admin",
        button_group: "manipulating",
      });
    }

    if (this.get("currentUser.staff")) {
      this.addActionButton({
        action: "topicOPBanUsers",
        className: "topic-OP-admin-silence-user",
        buttonClass: "popup-menu-btn",
        icon: "microphone-slash",
        fullLabel: "topic_op_admin.silence_user",
        button_group: "staff",
      });
    }

    if (topic.user_id !== this.get("currentUser.id")) {
      return;
    }

    if (!this.get("currentUser.can_manipulate_topic_op_adminable")) {
      this.addActionButton({
        action: "apply-for-op-admin",
        className: "topic-OP-admin-apply-for-op-admin",
        buttonClass: "popup-menu-btn",
        icon: "envelope-open-text",
        fullLabel: "topic_op_admin.apply_for_op_admin",
        button_group: "manipulating",
      });
    }

    // Admin actions
    if (topic.topic_op_admin_status.can_close) {
      if (topic.get("closed")) {
        this.addActionButton({
          className: "topic-OP-admin-open",
          buttonClass: "popup-menu-btn",
          action: "topicOPtoggleClose",
          icon: "unlock",
          label: "actions.open",
          button_group: "topic",
        });
      } else {
        this.addActionButton({
          className: "topic-OP-admin-close",
          buttonClass: "popup-menu-btn",
          action: "topicOPtoggleClose",
          icon: "lock",
          label: "actions.close",
          button_group: "topic",
        });
      }
    }
    if (topic.topic_op_admin_status.can_archive) {
      if (!isPrivateMessage) {
        this.addActionButton({
          className: "topic-OP-admin-archive",
          buttonClass: "popup-menu-btn",
          action: "topicOPtoggleArchived",
          icon: topic.get("archived") ? "folder-open" : "folder",
          label: topic.get("archived") ? "actions.unarchive" : "actions.archive",
          button_group: "topic",
        });
      }
    }
    if (topic.topic_op_admin_status.can_visible) {
      this.addActionButton({
        className: "topic-OP-admin-visible",
        buttonClass: "popup-menu-btn",
        action: "topicOPtoggleVisibility",
        icon: visible ? "far-eye-slash" : "far-eye",
        label: visible ? "actions.invisible" : "actions.visible",
        button_group: "topic",
      });
    }
    if (topic.topic_op_admin_status.can_slow_mode) {
      this.addActionButton({
        className: "topic-OP-admin-slow-mode",
        buttonClass: "popup-menu-btn",
        action: "topicOPShowTopicSlowModeUpdate",
        icon: "hourglass-start",
        label: "actions.slow_mode",
        button_group: "time",
      });
    }

    if (topic.topic_op_admin_status.can_set_timer) {
      this.addActionButton({
        className: "admin-topic-timer-update",
        buttonClass: "popup-menu-btn",
        action: "topicOPShowTopicTimerModal",
        icon: "far-clock",
        label: "actions.timed_update",
        button_group: "time",
      });
    }

    if (topic.topic_op_admin_status.can_make_PM) {
      this.addActionButton({
        className: "topic-admin-convert",
        buttonClass: "popup-menu-btn",
        action: isPrivateMessage
          ? "topicOPConvertToPublicTopic" // TODO: convert to Public
          : "topicOPConvertToPrivateMessage",
        icon: isPrivateMessage ? "comment" : "envelope",
        label: isPrivateMessage ? "actions.make_public" : "actions.make_private",
        button_group: "staff",
      });
    }

    if (topic.topic_op_admin_status.can_silence) {
      this.addActionButton({
        action: "topicOPBanUsers",
        className: "topic-OP-admin-silence-user",
        buttonClass: "popup-menu-btn",
        icon: "microphone-slash",
        fullLabel: "topic_op_admin.silence_user",
        button_group: "staff",
      });
    }
  },

  buildAttributes(attrs) {
    let { top, left, outerHeight } = attrs.position;
    const position = this.site.mobileView ? "fixed" : "absolute";

    if (attrs.rightSide) {
      return;
    }

    if (!attrs.openDownwards) {
      const documentHeight = $(document).height();
      const mainHeight = $(".ember-application").height();
      let bottom = documentHeight - top - 70 - $(".ember-application").offset().top;

      if (documentHeight > mainHeight) {
        bottom = bottom - (documentHeight - mainHeight) - outerHeight;
      }

      if (this.site.mobileView) {
        bottom = 50;
        left = 0;
      }

      return {
        style: `position: ${position}; bottom: ${bottom}px; left: ${left}px;`,
      };
    } else {
      return {
        style: `position: ${position}; top: ${top}px; left: ${left}px;`,
      };
    }
  },

  addActionButton(button) {
    this.attrs.actionButtons.push(button);
  },

  html(attrs) {
    const extraButtons = applyDecorators(this, "topicOPAdminMenuButtons", this.attrs, this.state);

    const actionButtons = attrs.actionButtons.concat(extraButtons).filter(Boolean);

    const buttonMap = actionButtons.reduce(
      (prev, current) => prev.set(current.button_group, [...(prev.get(current.button_group) || []), current]),
      new Map()
    );

    let combinedButtonLists = [];

    for (const [group, buttons] of buttonMap.entries()) {
      let buttonList = [];
      buttons.forEach((button) => {
        buttonList.push(this.attach("OP-admin-menu-button", button));
      });
      combinedButtonLists.push(h(`ul.topic-OP-admin-menu-${group}`, buttonList));
    }

    return h("ul", combinedButtonLists);
  },

  clickOutside() {
    this.sendWidgetAction("hideTopicOPAdminMenu");
  },
});
