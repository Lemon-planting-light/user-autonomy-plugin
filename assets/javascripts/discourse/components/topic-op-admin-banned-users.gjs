import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import { i18n } from "discourse-i18n";

export default class TopicOpAdminBannedUsers extends Component {
  @tracked unmute_user_ids = new Map();
  @tracked updated = 1;

  get users() {
    return this.args.users.map((u) => ({
      ...u,
      round: this.updated,
      banned_time: u.banned_seconds
        ? String(u.banned_seconds / 60)
        : i18n("topic_op_admin.silence_modal.forever"),
      banned_at: new Date(u.banned_at).toLocaleString(),
      in_unmute_user_ids: this.unmute_user_ids.has(u.id)
    }));
  }

  @action
  updateValue() {
    this.updated = 1;
    this.args.onUpdated?.(this);
  }

  @action
  unmute(u) {
    this.unmute_user_ids.set(u.id, u);
    this.updateValue();
  }

  @action
  mute(u) {
    this.unmute_user_ids.delete(u.id);
    this.updateValue();
  }

  get unmuteUserIds() {
    return this.unmute_user_ids.keys().toArray();
  }

  <template>
    <div>
      <table class="topic-OP-admin-banned-users">
        <thead>
          <tr class="clearfix small-user-list">
            <th class="banned-user">
              {{i18n "topic_op_admin.silence_modal.be_ban_user"}}
            </th>
            <th class="banned-at">
              {{i18n "topic_op_admin.silence_modal.be_ban_at"}}
            </th>
            <th class="banned-time">
              {{i18n "topic_op_admin.silence_modal.be_ban_time"}}
            </th>
          </tr>
        </thead>
        <tbody>
          {{#each this.users as |u|}}
            <tr class="clearfix small-user-list">
              <td class="banned-user">
                {{avatar u.avatar_template "small" (hash title=u.username)}}
                <span> {{u.username}} </span>
              </td>
              <td class="banned-at">
                {{u.banned_at}}
              </td>
              <td class="banned-time">
                {{u.banned_time}}
              </td>
              <td class="operation">
                {{#if u.in_unmute_user_ids}}
                  <DButton
                    @class="btn topic-OP-admin-unmute-button"
                    @icon="undo"
                    @label="topic_op_admin.silence_modal.recover"
                    @action={{fn this.mute u}}
                  />
                {{else}}
                  <DButton
                    @class="btn-danger topic-OP-admin-unmute-button"
                    @icon="times"
                    @label="topic_op_admin.silence_modal.unmute"
                    @action={{fn this.unmute u}}
                  />
                {{/if}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}
