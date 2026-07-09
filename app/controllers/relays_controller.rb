class RelaysController < ApplicationController
  before_action :set_yandex_service
  before_action :require_valid_token

  def index
    @devices = @yandex_service.get_devices
    @relays = @devices&.select { |d| d["type"] == "devices.types.switch" }
  end

  def turn_on
    result = @yandex_service.switch_device(params[:id], turn_on: true)
    flash[:alert] = "Не удалось включить реле" unless result&.is_a?(Net::HTTPSuccess)
    redirect_to relays_path
  end

  def turn_off
    result = @yandex_service.switch_device(params[:id], turn_on: false)
    flash[:alert] = "Не удалось выключить реле" unless result&.is_a?(Net::HTTPSuccess)
    redirect_to relays_path
  end

  private
  def set_yandex_service
    @yandex_service = YandexSmartHomeService.new(session[:yandex_token])
  end
end
