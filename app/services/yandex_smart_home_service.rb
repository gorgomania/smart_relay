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

  # Универсальный метод для включения/выключения
  def switch_device(device_id, turn_on: true)
    # Формируем тело запроса ровно так, как требует документация
    body = {
      devices: [ {
        id: device_id,
        actions: [ {
          type: "devices.capabilities.on_off",
          state: {
            instance: "on",
            value: turn_on # true = включить, false = выключить
          }
        } ]
      } ]
    }.to_json

    post_request("/v1.0/devices/actions", body)
  end

  # Удобные методы-обертки
  def turn_on(device_id)
    switch_device(device_id, turn_on: true)
  end

  def turn_off(device_id)
    switch_device(device_id, turn_on: false)
  end

  private

  # Вспомогательный метод для GET-запросов
  def get_request(path)
    uri = URI.parse(BASE_URL + path)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_response(response)
  end

  # Вспомогательный метод для POST-запросов
  def post_request(path, body)
    uri = URI.parse("https://api.iot.yandex.net#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {
      "Authorization" => "Bearer #{@token}",  # Токен доступа
      "Content-Type" => "application/json"
    })

    request.body = body
    response = http.request(request)

    Rails.logger.debug "Yandex API response: #{response.code} #{response.body}"

    response
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
