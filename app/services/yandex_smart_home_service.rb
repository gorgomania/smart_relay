require "net/http"
require "uri"
require "json"

class YandexSmartHomeService
  # Сбой запроса или устройства, текст можно показывать пользователю
  class Error < StandardError; end

  # Яндекс отклонил токен. Не наследует Error: обрабатывается отдельно, через повторный вход
  class UnauthorizedError < StandardError; end

  BASE_URL = "https://api.iot.yandex.net"
  TIMEOUT = 10

  # Timeout::Error покрывает Net::OpenTimeout, Net::ReadTimeout и Net::WriteTimeout,
  # SystemCallError — все Errno::*, IOError — EOFError
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError ].freeze

  # Коды и формулировки из документации Яндекса; прочие коды показываются как есть
  DEVICE_ERRORS = {
    "ACCOUNT_LINKING_ERROR" => "Ошибка в OAuth2 токене пользователя",
    "DEVICE_BUSY" => "Устройство занято",
    "DEVICE_NOT_FOUND" => "Устройство не найдено",
    "DEVICE_OFF" => "Устройство выключено",
    "DEVICE_UNREACHABLE" => "Устройство недоступно",
    "FIRMWARE_OUT_OF_DATE" => "Прошивка устарела",
    "HUMAN_INVOLVEMENT_NEEDED" => "Требуется вмешательство человека",
    "INTERNAL_ERROR" => "Неизвестная внутренняя ошибка",
    "INVALID_ACTION" => "Недопустимое действие",
    "INVALID_VALUE" => "Недопустимое значение",
    "NOT_SUPPORTED_IN_CURRENT_MODE" => "Не поддерживается в текущем режиме работы устройства",
    "REMOTE_CONTROL_DISABLED" => "Удаленное управление устройством отключено"
  }.freeze

  def initialize(token)
    @token = token
  end

  # Метод для получения информации о всех устройствах (чтобы найти нужное)
  def get_devices
    uri = URI.parse(BASE_URL + "/v1.0/user/info")

    perform(Net::HTTP::Get.new(uri)).fetch("devices", [])
  end

  def switch_device(device_id, turn_on: true)
    uri = URI.parse(BASE_URL + "/v1.0/devices/actions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {
      devices: [ {
        id: device_id,
        actions: [ {
          type: "devices.capabilities.on_off",
          state: { instance: "on", value: turn_on }
        } ]
      } ]
    }.to_json

    data = perform(request)
    action_result = data.dig("devices", 0, "capabilities", 0, "state", "action_result")
    raise Error, device_error_message(action_result) if action_result&.dig("status") == "ERROR"
  end

  private

  def device_error_message(action_result)
    code = action_result["error_code"]

    DEVICE_ERRORS.fetch(code) { action_result["error_message"].presence || code.presence || "Неизвестная ошибка устройства" }
  end

  def perform(request)
    request["Authorization"] = "Bearer #{@token}"
    uri = request.uri

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end

    parse_response(response)
  rescue *NETWORK_ERRORS => e
    Rails.logger.error "Yandex API connection error: #{e.class} #{e.message}"
    raise Error, "Нет соединения с Яндексом"
  end

  # Обработка ответа от API
  def parse_response(response)
    raise UnauthorizedError if response.is_a?(Net::HTTPUnauthorized)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Yandex API error: #{response.code} #{response.body}"
      raise Error, "Яндекс вернул ошибку #{response.code}"
    end

    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    Rails.logger.error "Yandex API invalid response: #{response.code} #{response.body}"
    raise Error, "Некорректный ответ от Яндекса"
  end
end
