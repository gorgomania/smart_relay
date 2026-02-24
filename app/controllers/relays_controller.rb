class RelaysController < ApplicationController
  before_action :set_yandex_service
  def index
    if session[:yandex_token].present?
      @devices = @yandex_service.get_devices
      # Фильтруем только устройства-реле (опционально)
      @relays = @devices&.select { |d| d["type"] == "devices.types.switch" }
    end
  end

  def turn_on
    device_id = params[:id]
    @yandex_service.turn_on(device_id)
    redirect_to relays_path
  end

  def turn_off
    device_id = params[:id]
    @yandex_service.turn_off(device_id)
    redirect_to relays_path
  end

  private
  def set_yandex_service
      @yandex_service = YandexSmartHomeService.new(session[:yandex_token])
  end
end
