require "net/http"
require "uri"
require "json"
require "securerandom"

class YandexAuthController < ApplicationController
  OAUTH_URL = "https://oauth.yandex.ru"
  # Имя, под которым вход виден пользователю в настройках Яндекс ID
  DEVICE_NAME = "Smart Relay"

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
      state: state,
      # Отозвать при выходе можно только токен, привязанный к устройству
      device_id: yandex_device_id,
      device_name: DEVICE_NAME
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
    # Токен хранится в cookie, поэтому без отзыва он продолжит работать в её копиях
    revoke_token(session[:yandex_token]) if session[:yandex_token].present?
    reset_session
    redirect_to yandex_auth_path, notice: "Вы вышли из системы"
  end

  private

  def valid_oauth_state?
    expected = session.delete(:yandex_oauth_state)

    expected.present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, expected)
  end

  # Постоянный идентификатор браузера: повторный вход не плодит новые устройства,
  # а у Яндекса не больше 30 токенов на устройства одного пользователя
  def yandex_device_id
    device_id = cookies.encrypted[:yandex_device_id]
    return device_id if device_id.present?

    device_id = SecureRandom.uuid
    cookies.permanent.encrypted[:yandex_device_id] = { value: device_id, httponly: true, same_site: :lax }
    device_id
  end

  def exchange_code_for_token(code)
    response = post_to_oauth("/token",
      grant_type: "authorization_code",
      code: code
    )
    return unless response

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body.to_s)
    else
      Rails.logger.error("Yandex token exchange failed: #{response.code} #{response.body}")
      nil
    end
  rescue JSON::ParserError
    # Только класс ошибки: текст JSON::ParserError содержит часть тела ответа, а в нём токен
    Rails.logger.error("Yandex token exchange failed: JSON::ParserError")
    nil
  end

  # Сбой отзыва не мешает выходу: сессия очищается в любом случае
  def revoke_token(token)
    response = post_to_oauth("/revoke_token", access_token: token)
    return if response.nil? || response.is_a?(Net::HTTPSuccess)

    Rails.logger.error("Yandex token revoke failed: #{response.code} #{response.body}")
  end

  def post_to_oauth(path, form)
    uri = URI(OAUTH_URL + path)
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(form.merge(client_id: ENV["YANDEX_CLIENT_ID"], client_secret: ENV["YANDEX_CLIENT_SECRET"]))

    timeout = YandexSmartHomeService::TIMEOUT
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: timeout, read_timeout: timeout) do |http|
      http.request(request)
    end
  rescue *YandexSmartHomeService::NETWORK_ERRORS => e
    Rails.logger.error("Yandex OAuth request #{path} failed: #{e.class}")
    nil
  end
end
