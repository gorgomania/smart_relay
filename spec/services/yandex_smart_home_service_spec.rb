require "rails_helper"

RSpec.describe YandexSmartHomeService do
  subject(:service) { described_class.new("test-token") }

  let(:devices_url) { "https://api.iot.yandex.net/v1.0/user/info" }
  let(:actions_url) { "https://api.iot.yandex.net/v1.0/devices/actions" }

  def action_response(action_result)
    { devices: [ { capabilities: [ { state: { action_result: action_result } } ] } ] }.to_json
  end

  describe "#get_devices" do
    it "возвращает устройства и передаёт токен" do
      stub = stub_request(:get, devices_url)
        .with(headers: { "Authorization" => "Bearer test-token" })
        .to_return(status: 200, body: { devices: [ { id: "1" } ] }.to_json)

      expect(service.get_devices).to eq([ { "id" => "1" } ])
      expect(stub).to have_been_requested
    end

    it "возвращает пустой список, если устройств нет" do
      stub_request(:get, devices_url).to_return(status: 200, body: "{}")

      expect(service.get_devices).to eq([])
    end

    it "бросает UnauthorizedError при 401" do
      stub_request(:get, devices_url).to_return(status: 401, body: "{}")

      expect { service.get_devices }.to raise_error(described_class::UnauthorizedError)
    end

    it "бросает Error при ответе 500" do
      stub_request(:get, devices_url).to_return(status: 500, body: "{}")

      expect { service.get_devices }.to raise_error(described_class::Error, /500/)
    end

    it "бросает Error при ответе не в формате JSON" do
      stub_request(:get, devices_url).to_return(status: 200, body: "<html></html>")

      expect { service.get_devices }.to raise_error(described_class::Error, "Некорректный ответ от Яндекса")
    end
  end

  describe "#switch_device" do
    [ true, false ].each do |value|
      it "отправляет команду со значением #{value}" do
        stub = stub_request(:post, actions_url)
          .with(body: hash_including(
            "devices" => [ {
              "id" => "relay-1",
              "actions" => [ {
                "type" => "devices.capabilities.on_off",
                "state" => { "instance" => "on", "value" => value }
              } ]
            } ]
          ))
          .to_return(status: 200, body: action_response(status: "DONE"))

        expect { service.switch_device("relay-1", turn_on: value) }.not_to raise_error
        expect(stub).to have_been_requested
      end
    end

    it "переводит код ошибки устройства в понятный текст" do
      stub_request(:post, actions_url)
        .to_return(status: 200, body: action_response(status: "ERROR", error_code: "DEVICE_UNREACHABLE"))

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, "Устройство недоступно")
    end

    it "для неизвестного кода показывает error_message из ответа" do
      stub_request(:post, actions_url).to_return(status: 200, body: action_response(
        status: "ERROR", error_code: "SOME_NEW_CODE", error_message: "Текст от Яндекса"
      ))

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, "Текст от Яндекса")
    end

    it "для неизвестного кода без error_message показывает сам код" do
      stub_request(:post, actions_url)
        .to_return(status: 200, body: action_response(status: "ERROR", error_code: "SOME_NEW_CODE"))

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, "SOME_NEW_CODE")
    end

    it "без кода и текста показывает общее сообщение" do
      stub_request(:post, actions_url).to_return(status: 200, body: action_response(status: "ERROR"))

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, "Неизвестная ошибка устройства")
    end

    it "бросает UnauthorizedError при 401" do
      stub_request(:post, actions_url).to_return(status: 401, body: "{}")

      expect { service.switch_device("relay-1") }.to raise_error(described_class::UnauthorizedError)
    end

    it "бросает Error при ответе 500 с JSON, а не считает его успехом" do
      stub_request(:post, actions_url).to_return(status: 500, body: { status: "error" }.to_json)

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, /500/)
    end

    it "бросает Error при ответе 502 с HTML" do
      stub_request(:post, actions_url).to_return(status: 502, body: "<html>bad gateway</html>")

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, /502/)
    end

    it "бросает Error при ответе 200 не в формате JSON" do
      stub_request(:post, actions_url).to_return(status: 200, body: "not json")

      expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, "Некорректный ответ от Яндекса")
    end
  end

  describe "сетевые сбои" do
    [
      Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ETIMEDOUT,
      SocketError, EOFError, OpenSSL::SSL::SSLError
    ].each do |error_class|
      it "превращает #{error_class} в Error" do
        stub_request(:any, /api\.iot\.yandex\.net/).to_raise(error_class)

        expect { service.get_devices }.to raise_error(described_class::Error, "Нет соединения с Яндексом")
        expect { service.switch_device("relay-1") }.to raise_error(described_class::Error, "Нет соединения с Яндексом")
      end
    end
  end
end
