import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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

export default class RequestTopicOpAdminForm extends Component {
  @service dialog;
  @service composer;
  @service currentUser;

  @tracked loading = false;
  @tracked reason = "";

  get topic() {
    return this.args.model.topic;
  }

  get textTemplate() {
    return i18n("topic_op_admin.apply_modal.apply_template").replaceAll("#", `[${this.topic.title}](${this.topic.url})`) +
      `\n${i18n("topic_op_admin.apply_modal.apply_reason")}\n`;
  }


  @action
  updateValue(event) {
    event.preventDefault();
    this.reason = event.target.value;
  }

  @action
  close() {
    this.args.closeModal();
  }

  @action
  submit() {
    this.loading = true;
    ajax("/topic_op_admin/request_for_topic_op_admin", {
      method: "POST",
      data: {
        id: this.topic.id,
        raw: `${this.textTemplate}${this.reason}`,
      },
    })
      .then((res) => {
        this.close();
        this.dialog.alert(res.message);
      })
      .finally(() => {
        this.loading = false;
      })
      .catch(popupAjaxError);
  }

  @action
  showComposer() {
    this.composer.openNewMessage({
      recipients: this.currentUser.op_admin_form_recipients.join(","),
      title: i18n("topic_op_admin.apply_modal.apply_template_title").replaceAll("#", this.topic.title),
      body: `${this.textTemplate}${this.reason}`,
      hasGroups: true,
    });
    this.close();
  }

  <template>
    <form class="request-op-admin-form">
      <DModal
        @title={{i18n "topic_op_admin.apply_for_op_admin"}}
        @closeModal={{@closeModal}}
      >
        <:body>
          <section class="reason">
            <h3>
              {{i18n "topic_op_admin.apply_modal.introduce_title"}}
            </h3>
            <p>
              {{i18n "topic_op_admin.apply_modal.what_is"}}
            </p>
            <hr />
          </section>
          <div class="control-group">
            <p>
              {{i18n "topic_op_admin.apply_modal.tell_reason"}}
            </p>

            <textarea
              {{on "input" this.updateValue}}
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
            @label="groups.membership_request.submit"
            @action={{this.submit}}
            @disabled={{this.loading}}
          />
          <DModalCancel @close={{@closeModal}} />
          <ConditionalLoadingSpinner
            @size="small"
            @condition={{this.loading}}
          />
          <div class="dock-right" style="margin-left: auto;margin-right: 0;">
            <DButton
              @class="btn-link"
              @label="topic_op_admin.apply_modal.show_composer"
              @action={{this.showComposer}}
            />
          </div>
        </:footer>
      </DModal>
    </form>
  </template>
}
