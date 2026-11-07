require "rails_helper"

RSpec.describe "YandexAuth", type: :request do
  let(:token_url) { "https://oauth.yandex.ru/token" }
  let(:failure_text) { "Не удалось получить токен" }

  describe "GET /auth/yandex/callback" do
    it "сохраняет токен и открывает список реле" do
      stub_request(:post, token_url)
        .with(body: hash_including("grant_type" => "authorization_code", "code" => "123"))
        .to_return(status: 200, body: { access_token: "test-token", expires_in: 3600 }.to_json)

      get yandex_callback_path, params: { code: "123" }

      expect(response).to redirect_to(relays_path)
      expect(session[:yandex_token]).to eq("test-token")
    end

    it "при неверном коде показывает ошибку" do
      stub_request(:post, token_url).to_return(status: 400, body: { error: "invalid_grant" }.to_json)

      get yandex_callback_path, params: { code: "wrong" }

      expect(response).to redirect_to(yandex_auth_path)
      expect(session[:yandex_token]).to be_nil

      follow_redirect!
      expect(response.body).to include(failure_text)
    end

    it "при ответе не в формате JSON показывает ошибку" do
      stub_request(:post, token_url).to_return(status: 200, body: "<html></html>")

      get yandex_callback_path, params: { code: "123" }

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to eq(failure_text)
    end

    it "при ответе без токена показывает ошибку" do
      stub_request(:post, token_url).to_return(status: 200, body: "{}")

      get yandex_callback_path, params: { code: "123" }

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to eq(failure_text)
    end

    [
      Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
      SocketError, EOFError, OpenSSL::SSL::SSLError
    ].each do |error_class|
      it "при #{error_class} показывает ошибку вместо 500" do
        stub_request(:post, token_url).to_raise(error_class)

        get yandex_callback_path, params: { code: "123" }

        expect(response).to redirect_to(yandex_auth_path)
        expect(flash[:alert]).to eq(failure_text)
      end
    end
  end
end
