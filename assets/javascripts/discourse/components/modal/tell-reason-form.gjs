import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class TellReasonForm extends Component {
  @tracked loading = false;
  @tracked reason = "";

  @action
  async submit() {
    this.loading = true;
    try {
      await this.args.model.submit(this);
    } catch (err) {
      popupAjaxError(err);
    }
    this.loading = false;
    this.close();
  }

  @action
  close() {
    this.args.closeModal();
  }

  @action
  updateValue(event) {
    event.preventDefault();
    this.reason = event.target.value;
  }

  <template>
    <form class="request-before-topic-op-admin-action-form">
      <DModal
        @title={{i18n "topic_op_admin.reason_modal.require_reason"}}
        @closeModal={{@closeModal}}
      >
        <:body>
          <div class="control-group">
            <p>
              {{i18n "topic_op_admin.reason_modal.tell_reason"}}
            </p>

            <textarea
              value={{this.reason}}
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
            @label="ok_value"
            @action={{this.submit}}
            @disabled={{this.loading}}
          />
          <DModalCancel @close={{@closeModal}} />
          <ConditionalLoadingSpinner
            @size="small"
            @condition={{this.loading}}
          />
        </:footer>
      </DModal>
    </form>
  </template>
}
