class RelaysController < ApplicationController
  # Выключатели и розетки включаются одинаково, через devices.capabilities.on_off
  RELAY_TYPES = %w[devices.types.switch devices.types.socket].freeze

  before_action :require_valid_token
  before_action :set_yandex_service

  rescue_from YandexSmartHomeService::UnauthorizedError, with: :expire_yandex_session

  def index
    devices = @yandex_service.get_devices
    @relays = devices.select { |d| RELAY_TYPES.include?(d["type"]) }
  rescue YandexSmartHomeService::Error => e
    flash.now[:alert] = "Не удалось загрузить список реле: #{e.message}"
  end

  def turn_on
    switch_relay(turn_on: true, failure_message: "Не удалось включить реле")
  end

  def turn_off
    switch_relay(turn_on: false, failure_message: "Не удалось выключить реле")
  end

  private
  def set_yandex_service
    @yandex_service = YandexSmartHomeService.new(session[:yandex_token])
  end

  def switch_relay(turn_on:, failure_message:)
    begin
      @yandex_service.switch_device(params[:id], turn_on: turn_on)
    rescue YandexSmartHomeService::Error => e
      flash[:alert] = "#{failure_message}: #{e.message}"
    end

    redirect_to relays_path
  end
end
