# frozen_string_literal: true

class Api::V1::Accounts::Inboxes::EmailConfigurationsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :authorize_email_configuration_access!

  def show
    render json: payload
  end

  def update
    config = @inbox.email_configuration || @inbox.build_email_configuration
    config.assign_attributes(permitted_params)
    config.save!
    render json: payload
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(inbox_id_param)
  end

  def authorize_email_configuration_access!
    authorize @inbox, :update?
  end

  def inbox_id_param
    params[:inbox_id] || params[:id]
  end

  def permitted_params
    params.require(:email_configuration).permit(:mail_from, :mail_subject)
  end

  def payload
    config = @inbox.email_configuration
    {
      mail_from: config&.mail_from,
      mail_subject: config&.mail_subject
    }
  end
end
