require "net/http"
require "uri"
require "json"
require "securerandom"

class YandexAuthController < ApplicationController
  before_action :redirect_if_authenticated, only: :index

  def index
  end
  # Это экшен, который перенаправляет пользователя на Яндекс
  def login
    # Одноразовый state защищает callback от подделки запроса (CSRF)
    state = SecureRandom.hex(32)
    session[:yandex_oauth_state] = state

    # Параметры приложения из .env
    client_id = ENV["YANDEX_CLIENT_ID"]
    # Формируем URL для перенаправления на Яндекс
    yandex_auth_url = "https://oauth.yandex.ru/authorize?" + {
      response_type: "code",
      client_id: client_id,
      redirect_uri: yandex_callback_url,
      scope: "iot:view iot:control",
      state: state
    }.to_query
    redirect_to yandex_auth_url, allow_other_host: true
  end

  # Это экшен, куда Яндекс вернет пользователя после подтверждения
  def callback
    # Проверяем, что вход начат в этом браузере, и только потом верим остальным параметрам
    unless valid_oauth_state?
      flash[:alert] = "Не удалось подтвердить вход, попробуйте снова"
      redirect_to yandex_auth_path and return
    end

    # Проверяем, не пришла ли ошибка
    if params[:error].present?
      flash[:alert] = "Ошибка авторизации: #{params[:error]}"
      redirect_to yandex_auth_path and return
    end

    # Получаем код из параметров
    code = params[:code]

    # Обмениваем код на токен
    token_data = exchange_code_for_token(code) if code.present?

    if token_data && token_data["access_token"].present?
      # Новая сессия при входе защищает от фиксации сессии
      reset_session
      # Сохраняем токен в сессии
      session[:yandex_token] = token_data["access_token"]
      session[:yandex_token_expires_at] = Time.now + token_data["expires_in"].to_i if token_data["expires_in"]
      flash[:notice] = "Успешная авторизация!"
      redirect_to relays_path and return
    else
      flash[:alert] = "Не удалось получить токен"
      redirect_to yandex_auth_path
    end
  end

  def logout
    session[:yandex_token] = nil
    session[:yandex_token_expires_at] = nil
    redirect_to yandex_auth_path, notice: "Вы вышли из системы"
  end

  private

  def valid_oauth_state?
    expected = session.delete(:yandex_oauth_state)

    expected.present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, expected)
  end

  def exchange_code_for_token(code)
    uri = URI("https://oauth.yandex.ru/token")

    # Параметры для обмена кода на токен
    params = {
      grant_type: "authorization_code",
      code: code,
      client_id: ENV["YANDEX_CLIENT_ID"],
      client_secret: ENV["YANDEX_CLIENT_SECRET"]
    }

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(params)

    timeout = YandexSmartHomeService::TIMEOUT
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: timeout, read_timeout: timeout) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body.to_s)
    else
      Rails.logger.error("Yandex token exchange failed: #{response.code} #{response.body}")
      nil
    end
  rescue *YandexSmartHomeService::NETWORK_ERRORS, JSON::ParserError => e
    # Только класс ошибки: текст JSON::ParserError содержит часть тела ответа
    Rails.logger.error("Yandex token exchange failed: #{e.class}")
    nil
  end
end
