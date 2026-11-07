module YandexAuthHelpers
  # Начинает вход как браузер и возвращает state, с которым Яндекс вернёт пользователя
  def begin_login
    get yandex_login_path

    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end

  def stub_token_exchange(body = { access_token: "test-token", expires_in: 3600 })
    stub_request(:post, "https://oauth.yandex.ru/token").to_return(status: 200, body: body.to_json)
  end

  # Вход через настоящий callback: сессию в request-спеках напрямую не задать
  def sign_in(token_response = { access_token: "test-token", expires_in: 3600 })
    stub_token_exchange(token_response)
    get yandex_callback_path, params: { code: "123", state: begin_login }
  end
end

RSpec.configure do |config|
  config.include YandexAuthHelpers, type: :request
end
