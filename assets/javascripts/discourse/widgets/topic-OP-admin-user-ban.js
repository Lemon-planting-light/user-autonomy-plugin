/* eslint-disable no-unused-vars */
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { avatarFor } from "discourse/widgets/post";
import I18n from "I18n";

createWidget("topic-OP-admin-unmute-button", {
  tagName: "td",

  buildClasses: () => "operation",

  html(attrs) {
    if (this.attrs.parent.new_unmute_users.includes(this.attrs.user.id)) {
      return this.attach("button", {
        className: "btn topic-OP-admin-unmute-button",
        action: "recoverBannedRecord",
        icon: "undo",
        label: "topic_op_admin.silence_modal.recover",
      });
    } else {
      return this.attach("button", {
        className: "btn-danger topic-OP-admin-unmute-button",
        action: "deleteBannedRecord",
        icon: "times",
        label: "topic_op_admin.silence_modal.unmute",
      });
    }
  },

  recoverBannedRecord() {
    this.attrs.parent.new_unmute_users = this.attrs.parent.new_unmute_users.filter((i) => i !== this.attrs.user.id);
  },
  deleteBannedRecord() {
    this.attrs.parent.new_unmute_users.push(this.attrs.user.id);
  },
});

// createWidget("topic-OP-admin-user-ban-line", {
//   tagName: "tr",

//   buildClasses: () => "clearfix",

//   html(attrs) {
//     console.log(attrs);

//   }
// });

export default createWidget("topic-OP-admin-user-ban", {
  tagName: "div",

  buildClasses: () => "topic-OP-admin-user-ban",

  html(attrs) {
    const userlists = [
      h("tr.clearfix.small-user-list", [
        h("td.bannedd-user", I18n.t("topic_op_admin.silence_modal.be_ban_user")),
        h("td.banned-at", I18n.t("topic_op_admin.silence_modal.be_ban_at")),
        h("td.banned-time", I18n.t("topic_op_admin.silence_modal.be_ban_time")),
      ]),
    ];

    for (const u of attrs.users) {
      const minutes = u.banned_seconds ? String(u.banned_seconds / 60) : I18n.t("topic_op_admin.silence_modal.forever");
      userlists.push(
        h("tr.clearfix.small-user-list", [
          h("td.bannedd-user", [
            avatarFor("small", {
              username: u.username,
              template: u.avatar_template,
              url: `/u/${u.username}`,
            }),
            h("span", u.username),
          ]),
          h("td.banned-at", new Date(u.banned_at).toLocaleString()),
          h("td.banned-time", minutes),
          this.attach("topic-OP-admin-unmute-button", {
            user: u,
            parent: attrs,
          }),
        ])
      );
    }

    return h("table.topic-OP-admin-banned-users", h("tbody", userlists));
  },
});
