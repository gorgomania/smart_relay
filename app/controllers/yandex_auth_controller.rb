# app/controllers/yandex_auth_controller.rb
class YandexAuthController < ApplicationController
  # Это экшен, который перенаправляет пользователя на Яндекс
  def login
    # Параметры приложения из .env
    client_id = ENV["YANDEX_CLIENT_ID"]
    redirect_uri = "https://oauth.yandex.ru/verification_code"
    # Формируем URL для перенаправления на Яндекс
    yandex_auth_url = "https://oauth.yandex.ru/authorize?" + {
      response_type: "code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: "iot:view iot:control"
    }.to_query
    redirect_to yandex_auth_url, allow_other_host: true
  end

  # Это экшен, куда Яндекс вернет пользователя после подтверждения
  def callback
    # Проверяем, не пришла ли ошибка
    if params[:error].present?
      flash[:alert] = "Ошибка авторизации: #{params[:error]}"
      redirect_to root_path and return
    end

    # Получаем код из параметров
    code = params[:code]

    # Обмениваем код на токен
    token_data = exchange_code_for_token(code)

    if token_data && token_data["access_token"].present?
      # Сохраняем токен в сессии
      session[:yandex_token] = token_data["access_token"]
      session[:yandex_token_expires_at] = Time.now + token_data["expires_in"].to_i if token_data["expires_in"]
      flash[:notice] = "Успешная авторизация!"
    else
      flash[:alert] = "Не удалось получить токен"
    end
    redirect_to root_path
  end

  def logout
    session[:yandex_token] = nil
    redirect_to root_path, notice: "Вы вышли из системы"
  end

  private

  def exchange_code_for_token(code)
    uri = URI("https://oauth.yandex.ru/token")

    # Параметры для обмена кода на токен
    params = {
      grant_type: "authorization_code",
      code: code,
      client_id: ENV["YANDEX_CLIENT_ID"],
      client_secret: ENV["YANDEX_CLIENT_SECRET"]
    }

    response = Net::HTTP.post_form(uri, params)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error("Yandex token exchange failed: #{response.body}")
      nil
    end
  end
end
