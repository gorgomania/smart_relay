class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

private

  def yandex_token_valid?
    return false unless session[:yandex_token].present?

    expires_at = session[:yandex_token_expires_at]
    return true if expires_at.nil?

    Time.now < Time.parse(expires_at.to_s)
  end

  def require_valid_token
    return unless session[:yandex_token].present?
    return if yandex_token_valid?

    session[:yandex_token] = nil
    session[:yandex_token_expires_at] = nil
    redirect_to root_path, alert: "Сессия истекла, авторизуйтесь снова"
  end
end
