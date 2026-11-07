require "rails_helper"
require "support/yandex_auth_helpers"

RSpec.describe "YandexAuth", type: :request do
  let(:token_url) { "https://oauth.yandex.ru/token" }
  let(:failure_text) { "Не удалось получить токен" }
  let(:state_failure_text) { "Не удалось подтвердить вход, попробуйте снова" }

  describe "GET /auth" do
    it "показывает ссылку на вход без Turbo и без формы ввода кода" do
      get yandex_auth_path

      expect(response.body).to include("Войти через Яндекс")
      expect(response.body).to include('data-turbo="false"')
      expect(response.body).not_to include("<form")
    end
  end

  describe "GET /auth/yandex/login" do
    it "отправляет на Яндекс с адресом возврата в приложение и state" do
      get yandex_login_path

      uri = URI(response.location)
      query = Rack::Utils.parse_query(uri.query)

      expect(uri.host).to eq("oauth.yandex.ru")
      expect(query).to include(
        "response_type" => "code",
        "scope" => "iot:view iot:control",
        "redirect_uri" => yandex_callback_url
      )
      expect(query["state"]).to match(/\A\h{64}\z/)
    end

    it "выдаёт новый state при каждом входе" do
      expect(begin_login).not_to eq(begin_login)
    end
  end

  describe "GET /auth/yandex/callback" do
    it "сохраняет токен и открывает список реле" do
      stub = stub_request(:post, token_url)
        .with(body: hash_including("grant_type" => "authorization_code", "code" => "123"))
        .to_return(status: 200, body: { access_token: "test-token", expires_in: 3600 }.to_json)

      get yandex_callback_path, params: { code: "123", state: begin_login }

      expect(response).to redirect_to(relays_path)
      expect(session[:yandex_token]).to eq("test-token")
      expect(session[:yandex_oauth_state]).to be_nil
      expect(stub).to have_been_requested
    end

    context "когда state не проходит проверку" do
      before { stub_token_exchange }

      it "отклоняет запрос без state" do
        begin_login

        get yandex_callback_path, params: { code: "123" }

        expect(response).to redirect_to(yandex_auth_path)
        expect(flash[:alert]).to eq(state_failure_text)
        expect(session[:yandex_token]).to be_nil
      end

      it "отклоняет неверный state" do
        begin_login

        get yandex_callback_path, params: { code: "123", state: "wrong" }

        expect(flash[:alert]).to eq(state_failure_text)
        expect(session[:yandex_token]).to be_nil
      end

      it "отклоняет state в виде массива без ошибки 500" do
        begin_login

        get yandex_callback_path, params: { code: "123", state: [ "wrong" ] }

        expect(response).to redirect_to(yandex_auth_path)
        expect(flash[:alert]).to eq(state_failure_text)
      end

      it "отклоняет запрос, если вход не начинался" do
        get yandex_callback_path, params: { code: "123", state: "anything" }

        expect(flash[:alert]).to eq(state_failure_text)
      end

      it "не принимает один state дважды" do
        state = begin_login
        get yandex_callback_path, params: { code: "wrong", state: "wrong" }

        get yandex_callback_path, params: { code: "123", state: state }

        expect(flash[:alert]).to eq(state_failure_text)
        expect(session[:yandex_token]).to be_nil
      end

      it "не обращается к Яндексу" do
        begin_login

        get yandex_callback_path, params: { code: "123", state: "wrong" }

        expect(a_request(:post, token_url)).not_to have_been_made
      end
    end

    it "показывает ошибку, если пользователь отказался от входа" do
      get yandex_callback_path, params: { error: "access_denied", state: begin_login }

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to eq("Ошибка авторизации: access_denied")
    end

    it "без кода показывает ошибку и не обращается к Яндексу" do
      get yandex_callback_path, params: { state: begin_login }

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to eq(failure_text)
      expect(a_request(:post, token_url)).not_to have_been_made
    end

    it "при неверном коде показывает ошибку" do
      stub_request(:post, token_url).to_return(status: 400, body: { error: "invalid_grant" }.to_json)

      get yandex_callback_path, params: { code: "wrong", state: begin_login }

      expect(response).to redirect_to(yandex_auth_path)
      expect(session[:yandex_token]).to be_nil

      follow_redirect!
      expect(response.body).to include(failure_text)
    end

    it "при ответе не в формате JSON показывает ошибку" do
      stub_request(:post, token_url).to_return(status: 200, body: "<html></html>")

      get yandex_callback_path, params: { code: "123", state: begin_login }

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to eq(failure_text)
    end

    it "при ответе без токена показывает ошибку" do
      stub_request(:post, token_url).to_return(status: 200, body: "{}")

      get yandex_callback_path, params: { code: "123", state: begin_login }

      expect(response).to redirect_to(yandex_auth_path)
      expect(flash[:alert]).to eq(failure_text)
    end

    [
      Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
      SocketError, EOFError, OpenSSL::SSL::SSLError
    ].each do |error_class|
      it "при #{error_class} показывает ошибку вместо 500" do
        stub_request(:post, token_url).to_raise(error_class)

        get yandex_callback_path, params: { code: "123", state: begin_login }

        expect(response).to redirect_to(yandex_auth_path)
        expect(flash[:alert]).to eq(failure_text)
      end
    end
  end
end
