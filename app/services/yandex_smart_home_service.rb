require "net/http"
require "uri"
require "json"

class YandexSmartHomeService
  BASE_URL = "https://api.iot.yandex.net"

  def initialize(token)
    @token = token
  end

  # Метод для получения информации о всех устройствах (чтобы найти нужное)
  def get_devices
    get_request("/v1.0/user/info")&.dig("devices")
  end

  def switch_device(device_id, turn_on: true)
    body = {
      devices: [ {
        id: device_id,
        actions: [ {
          type: "devices.capabilities.on_off",
          state: { instance: "on", value: turn_on }
        } ]
      } ]
    }.to_json

    response = post_request("/v1.0/devices/actions", body)
    return "Нет соединения с Яндексом" unless response

    data = JSON.parse(response.body)
    action_result = data.dig("devices", 0, "capabilities", 0, "state", "action_result")
    return action_result["error_code"] if action_result&.dig("status") == "ERROR"

    nil
  end

  private

  TIMEOUT = 10

  NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError ].freeze

  def get_request(path)
    uri = URI.parse(BASE_URL + path)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end

    handle_response(response)
  rescue *NETWORK_ERRORS => e
    Rails.logger.error "Yandex API connection error: #{e.message}"
    nil
  end

  def post_request(path, body)
    uri = URI.parse(BASE_URL + path)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Content-Type"] = "application/json"
    request.body = body

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end

    Rails.logger.debug "Yandex API response: #{response.code} #{response.body}"

    response
  rescue *NETWORK_ERRORS => e
    Rails.logger.error "Yandex API connection error: #{e.message}"
    nil
  end

  # Обработка ответа от API
  def handle_response(response)
    if response.is_a?(Net::HTTPSuccess)
      return nil if response.body.empty?
      JSON.parse(response.body)
    else
      # В реальном приложении здесь стоит использовать Rails.logger
      Rails.logger.error "Yandex API error: #{response.code} #{response.body}"
      nil
    end
  end
end
