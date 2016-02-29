class ApplicationController < ActionController::Base
  include GDS::SSO::ControllerMethods

  class BadRequest < StandardError; end

  rescue_from CommandError, with: :respond_with_command_error
  rescue_from BadRequest do
    head :bad_request
  end

  before_action do
    # Force Rails to show text-error pages
    request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
  end

  before_action :require_signin_permission!

  Warden::Manager.after_authentication do |user, _, _|
    user.set_app_name!
  end

private

  def respond_with_command_error(error)
    render status: error.code, json: error
  end

  def base_path
    "/#{params[:base_path]}"
  end

  def payload
    @payload ||= JSON.parse(request.body.read).deep_symbolize_keys
  rescue JSON::ParserError
    raise BadRequest
  end
end
