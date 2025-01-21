import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class SetTopicOpAdminStatusModal extends Component {
  @service currentUser;
  @service dialog;
  @service siteSettings;
  @tracked loading = false;

  get topic() {
    return this.args.model.topic;
  }

  get enables() {
    return this.args.model.enables;
  }

  get canSetPostFolding() {
    return this.siteSettings.discourse_post_folding_enabled;
  }

  @action
  submit() {
    if (this.loading) {
      return;
    }
    this.loading = true;
    ajax("/topic_op_admin/set_topic_op_admin_status", {
      method: "POST",
      data: {
        id: this.topic.id,
        new_status: this.enables,
      },
    })
      .then((res) => {
        this.args.closeModal();
        if (!res.success) {
          this.dialog.alert(res.message);
        } else {
          this.args.model.cb(this);
          // window.location.reload();
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
      });
  }
}
