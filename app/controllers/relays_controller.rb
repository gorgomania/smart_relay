class RelaysController < ApplicationController
  # before_action :require_yandex_token
  # before_action :set_yandex_service

  def index
    if session[:yandex_token].present?
      @yandex_service = YandexSmartHomeService.new(session[:yandex_token])
      @devices = @yandex_service.get_devices
      # Фильтруем только устройства-реле (опционально)
      @relays = @devices&.select { |d| d["type"] == "devices.types.switch.relay" }
    end
  end

  def turn_on
    device_id = params[:id]
    if @yandex_service.turn_on(device_id)
      flash[:notice] = "Устройство включено"
    else
      flash[:alert] = "Не удалось включить устройство"
    end
    redirect_to button_path
  end

  def turn_off
    device_id = params[:id]
    if @yandex_service.turn_off(device_id)
      flash[:notice] = "Устройство выключено"
    else
      flash[:alert] = "Не удалось выключить устройство"
    end
    redirect_to relays_path
  end
end
