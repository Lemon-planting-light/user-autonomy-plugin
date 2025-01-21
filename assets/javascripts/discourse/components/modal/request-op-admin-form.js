import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
// import { on } from "@ember/modifier";
// import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
// import DButton from "discourse/components/d-button";
// import DModal from "discourse/components/d-modal";
// import DModalCancel from "discourse/components/d-modal-cancel";
// import i18n from "discourse-common/helpers/i18n";

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
    return (
      i18n("topic_op_admin.apply_modal.apply_template").replaceAll(
        "#",
        `[${this.topic.title}](${this.topic.url})`
      ) + `\n${i18n("topic_op_admin.apply_modal.apply_reason")}\n`
    );
  }

  @action
  updateValue(event) {
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
      title: i18n("topic_op_admin.apply_modal.apply_template_title").replaceAll(
        "#",
        this.topic.title
      ),
      body: `${this.textTemplate}${this.reason}`,
      hasGroups: true,
    });
    this.close();
  }
}
