require "rails_helper"

RSpec.describe "Relays", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:devices_url) { "https://api.iot.yandex.net/v1.0/user/info" }
  let(:actions_url) { "https://api.iot.yandex.net/v1.0/devices/actions" }
  let(:relay) do
    {
      id: "relay-1",
      name: "Свет в гараже",
      type: "devices.types.switch",
      capabilities: [ { type: "devices.capabilities.on_off", state: { value: false } } ]
    }
  end
  let(:not_found_text) { "Устройства не найдены" }
  let(:expired_text) { "Сессия истекла, авторизуйтесь снова" }

  # Вход через настоящий callback: сессию в request-спеках напрямую не задать
  def sign_in(token_response = { access_token: "test-token", expires_in: 3600 })
    stub_request(:post, "https://oauth.yandex.ru/token").to_return(status: 200, body: token_response.to_json)
    get yandex_callback_path, params: { code: "123" }
  end

  def stub_action(status: 200, body: { devices: [] }.to_json)
    stub_request(:post, actions_url).to_return(status: status, body: body)
  end

  describe "GET /relays" do
    before { sign_in }

    it "показывает реле и скрывает другие устройства" do
      stub_request(:get, devices_url).to_return(status: 200, body: {
        devices: [ relay, { id: "lamp", name: "Лампа", type: "devices.types.light", capabilities: [] } ]
      }.to_json)

      get relays_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Свет в гараже")
      expect(response.body).not_to include("Лампа")
    end

    it "сообщает, что устройств нет, если реле не найдены" do
      stub_request(:get, devices_url).to_return(status: 200, body: { devices: [] }.to_json)

      get relays_path

      expect(response.body).to include(not_found_text)
    end

    it "показывает ошибку соединения вместо сообщения об отсутствии устройств" do
      stub_request(:get, devices_url).to_timeout

      get relays_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Не удалось загрузить список реле: Нет соединения с Яндексом")
      expect(response.body).not_to include(not_found_text)
    end

    it "показывает ошибку при ответе 500" do
      stub_request(:get, devices_url).to_return(status: 500, body: "{}")

      get relays_path

      expect(response.body).to include("Яндекс вернул ошибку 500")
      expect(response.body).not_to include(not_found_text)
    end

    it "показывает ошибку при непредвиденном сбое SSL вместо 500" do
      stub_request(:get, devices_url).to_raise(OpenSSL::SSL::SSLError)

      get relays_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Нет соединения с Яндексом")
    end
  end

  { turn_on: "включить", turn_off: "выключить" }.each do |action, verb|
    describe "POST /relays/:id/#{action}" do
      let(:path) { public_send("#{action}_relay_path", "relay-1") }

      before do
        sign_in
        stub_request(:get, devices_url).to_return(status: 200, body: { devices: [ relay ] }.to_json)
      end

      it "при успехе возвращает к списку без ошибки" do
        stub_action

        post path

        expect(response).to redirect_to(relays_path)
        expect(flash[:alert]).to be_nil
      end

      it "показывает понятный текст ошибки устройства" do
        stub_action(body: {
          devices: [ { capabilities: [ { state: { action_result: { status: "ERROR", error_code: "DEVICE_UNREACHABLE" } } } ] } ]
        }.to_json)

        post path
        follow_redirect!

        expect(response.body).to include("Не удалось #{verb} реле: Устройство недоступно")
      end

      it "показывает ошибку при таймауте" do
        stub_request(:post, actions_url).to_timeout

        post path

        expect(flash[:alert]).to eq("Не удалось #{verb} реле: Нет соединения с Яндексом")
      end

      it "показывает ошибку при ответе 500" do
        stub_action(status: 500, body: { status: "error" }.to_json)

        post path

        expect(flash[:alert]).to eq("Не удалось #{verb} реле: Яндекс вернул ошибку 500")
      end

      it "показывает ошибку при HTML-ответе 502" do
        stub_action(status: 502, body: "<html>bad gateway</html>")

        post path

        expect(response).to redirect_to(relays_path)
        expect(flash[:alert]).to eq("Не удалось #{verb} реле: Яндекс вернул ошибку 502")
      end

      it "при 401 сбрасывает сессию и отправляет на вход" do
        stub_action(status: 401, body: "{}")

        post path

        expect(response).to redirect_to(yandex_auth_path)
        expect(session[:yandex_token]).to be_nil
      end
    end
  end

  describe "авторизация" do
    it "без токена отправляет на вход без сообщения об истёкшей сессии" do
      get relays_path

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to be_nil
    end

    it "при истёкшем сроке токена отправляет на вход с сообщением" do
      sign_in

      travel 2.hours do
        get relays_path

        expect(response).to redirect_to(yandex_auth_path)
        expect(session[:yandex_token]).to be_nil

        follow_redirect!
        expect(response.body).to include(expired_text)
      end
    end

    it "при 401 от Яндекса на списке сбрасывает сессию и показывает сообщение" do
      sign_in
      stub_request(:get, devices_url).to_return(status: 401, body: "{}")

      get relays_path

      expect(response).to redirect_to(yandex_auth_path)
      expect(session[:yandex_token]).to be_nil

      follow_redirect!
      expect(response.body).to include(expired_text)
      expect(response.body).not_to include(not_found_text)
    end

    it "при 401 сбрасывает и токен без срока действия" do
      sign_in(access_token: "test-token")
      stub_request(:get, devices_url).to_return(status: 401, body: "{}")

      get relays_path

      expect(response).to redirect_to(yandex_auth_path)
      expect(session[:yandex_token]).to be_nil
    end
  end
end
