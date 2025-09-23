import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const KEYS = [
  "can_close",
  "can_archive",
  "can_visible",
  "can_slow_mode",
  "can_set_timer",
  "can_make_PM",
  "can_silence",
  "can_fold_posts",
];

export default class SetTopicOpAdminStatusModal extends Component {
  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked loading = false;
  @tracked status = {};

  constructor() {
    super(...arguments);

    this.status = Object.fromEntries(
      KEYS.map((k) => [
        k,
        this.args.model.topic.topic_op_admin_status?.[k] ?? false,
      ])
    );
  }

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
  toggleEnabled(flag) {
    this.status = {
      ...this.status,
      [flag]: !this.status[flag],
    };
  }

  @action
  submit() {
    if (this.loading) {
      return;
    }
    this.loading = true;
    ajax(`/topic-op-admin/set-topic-op-admin-status/${this.topic.id}`, {
      method: "POST",
      data: this.status,
    })
      .then(() => {
        this.args.closeModal();
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
      });
  }

  <template>
    <DModal
      @title={{i18n "topic_op_admin.admin_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="set-topic-op-admin-status-modal-body">
          <h3>
            {{i18n "topic.title"}}
            {{this.topic.title}}
          </h3>
          <div class="control-group topic-op-admin-status normal">
            <div>
              <DToggleSwitch
                @state={{this.status.can_close}}
                {{on "click" (fn this.toggleEnabled "can_close")}}
              />
              <span>{{i18n "topic_op_admin.admin_modal.enable_close"}}</span>
            </div>
            <div>
              <DToggleSwitch
                @state={{this.status.can_archive}}
                {{on "click" (fn this.toggleEnabled "can_archive")}}
              />
              <span>{{i18n "topic_op_admin.admin_modal.enable_archive"}}</span>
            </div>
            <div>
              <DToggleSwitch
                @state={{this.status.can_visible}}
                {{on "click" (fn this.toggleEnabled "can_visible")}}
              />
              <span>{{i18n "topic_op_admin.admin_modal.enable_visible"}}</span>
            </div>
            <div>
              <DToggleSwitch
                @state={{this.status.can_slow_mode}}
                {{on "click" (fn this.toggleEnabled "can_slow_mode")}}
              />
              <span>{{i18n
                  "topic_op_admin.admin_modal.enable_slow_mode"
                }}</span>
            </div>
            <div>
              <DToggleSwitch
                @state={{this.status.can_set_timer}}
                {{on "click" (fn this.toggleEnabled "can_set_timer")}}
              />
              <span>{{i18n
                  "topic_op_admin.admin_modal.enable_set_timer"
                }}</span>
            </div>
          </div>

          {{#if this.currentUser.staff}}
            <div class="control-group topic-op-admin-status staff">
              <hr />
              <div>
                <DToggleSwitch
                  @state={{this.status.can_make_PM}}
                  {{on "click" (fn this.toggleEnabled "can_make_PM")}}
                />
                <span>{{i18n
                    "topic_op_admin.admin_modal.enable_make_PM"
                  }}</span>
              </div>
              <div>
                <DToggleSwitch
                  @state={{this.status.can_silence}}
                  {{on "click" (fn this.toggleEnabled "can_silence")}}
                />
                <span>{{i18n
                    "topic_op_admin.admin_modal.enable_silence"
                  }}</span>
              </div>
            </div>
          {{/if}}
          {{#if this.canSetPostFolding}}
            <div class="control-group topic-op-admin-status plugins">
              <hr />
              <div>
                <DToggleSwitch
                  @state={{this.status.can_fold_posts}}
                  {{on "click" (fn this.toggleEnabled "can_fold_posts")}}
                />
                <span>{{i18n
                    "topic_op_admin.admin_modal.enable_fold_posts"
                  }}</span>
              </div>
            </div>
          {{/if}}
        </div>
      </:body>
      <:footer>
        <DButton
          @label="ok_value"
          @icon="check"
          @action={{this.submit}}
          class="btn-primary"
          @disabled={{this.loading}}
        />
        <ConditionalLoadingSpinner @size="small" @condition={{this.loading}} />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
