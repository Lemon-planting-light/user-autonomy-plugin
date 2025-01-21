import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import UserChooser from "select-kit/components/user-chooser";
import TopicOpAdminBannedUsers from "../topic-op-admin-banned-users";

export default class TopicOpAdminSilenceUserModal extends Component {
  @service dialog;
  @service composer;
  @service currentUser;

  @tracked submitting = false;
  @tracked loading = true;
  @tracked reason = "";
  @tracked silence_time;
  @tracked banned_users;
  @tracked new_ban_users = [];
  @tracked new_unmute_users = [];

  constructor(...args) {
    super(...args);
    this.loadBannedUsers();
  }

  loadBannedUsers() {
    ajax("/topic_op_admin/get_topic_op_banned_users", {
      method: "GET",
      data: {
        id: this.topic.id,
      },
    })
      .then((res) => {
        this.loading = false;
        this.banned_users = res.users;
      })
      .catch(popupAjaxError);
  }

  get topic() {
    return this.args.model.topic;
  }

  @action
  setUnmute(attr) {
    this.new_unmute_users = attr.unmuteUserIds;
  }

  @action
  close() {
    this.args.closeModal();
  }

  @action
  updateReason(event) {
    event.preventDefault();
    this.reason = event.target.value;
  }

  @action
  updateSilenceTime(event) {
    event.preventDefault();
    this.silence_time = event.target.value;
  }

  @action
  submit() {
    if (this.new_ban_users.length === 0 && this.new_unmute_users.length === 0) {
      this.close();
      return;
    }
    let seconds;
    if (this.silence_time !== "") {
      seconds = Number(this.silence_time) * 60;
    } else {
      seconds = null;
    }
    if (this.reason === "") {
      this.dialog.alert(i18n("topic_op_admin.reason_modal.alert_no_reason"));
      return;
    }
    this.submitting = true;
    ajax("/topic_op_admin/update_topic_op_banned_users", {
      method: "PUT",
      data: {
        id: this.topic.id,
        new_silence_users: this.new_ban_users,
        seconds,
        new_unmute_users: this.new_unmute_users,
        reason: this.reason,
      },
    })
      .then((res) => {
        this.close();
        if (!res.success) {
          this.dialog.alert(res.message);
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.submitting = false;
      });
  }

  <template>
    <DModal
      @title={{i18n "topic_op_admin.silence_user"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <ConditionalLoadingSpinner @size="large" @condition={{this.loading}}>
          <div class="topic-OP-banned-users-container control-group">
            {{#if this.banned_users}}
              <p>
                {{i18n "topic_op_admin.silence_modal.banned_users"}}
              </p>
              <TopicOpAdminBannedUsers
                @users={{this.banned_users}}
                @onUpdated={{this.setUnmute}}
              />
            {{/if}}
          </div>
        </ConditionalLoadingSpinner>

        <p>
          {{i18n "topic_op_admin.silence_modal.banning_users"}}
        </p>
        <div class="input-group">
          <table class="topic-OP-admin-banned-users new-ban">
            <tbody>
              <tr>
                <td>
                  {{i18n "topic_op_admin.silence_modal.be_ban_user"}}
                </td>
                <td>
                  {{i18n "topic_op_admin.silence_modal.be_ban_time"}}
                </td>
              </tr>
              <tr>
                <td>
                  <UserChooser
                    class="topic-op-make-silence-user"
                    @value={{this.new_ban_users}}
                    @options={{hash topicId=this.topic.id}}
                  />
                </td>
                <td>
                  <input
                    class="topic-op-silence-time"
                    maxlength="10"
                    type="number"
                    value={{this.silence_time}}
                    {{on "input" this.updateSilenceTime}}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="control-group">
          <p>
            {{i18n "topic_op_admin.reason_modal.tell_reason"}}
          </p>

          <textarea
            value={{this.reason}}
            {{on "input" this.updateReason}}
            min-width="500px"
            min-height="400px"
            max-height="1000px"
            resize="both"
          />
        </div>
      </:body>
      <:footer>
        <DButton
          @class="btn-primary"
          @label="ok_value"
          @action={{this.submit}}
          @disabled={{this.submitting}}
        />
        <DModalCancel @close={{@closeModal}} />
        <ConditionalLoadingSpinner
          @size="small"
          @condition={{this.submitting}}
        />

      </:footer>
    </DModal>
  </template>
}
