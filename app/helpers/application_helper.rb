module ApplicationHelper
  FLASH_COLORS = {
    "notice" => "border-[#0a9130] text-[#0a9130] bg-[#a0e7b1]"
  }.freeze
  FLASH_ERROR_COLORS = "border-red-800 text-red-800 bg-red-200".freeze

  def flash_messages
    flash.each do |type, msg|
      colors = FLASH_COLORS.fetch(type, FLASH_ERROR_COLORS)
      concat(content_tag(:div, msg, class: "mt-5 px-3 h-16 w-full border #{colors} rounded-lg flex items-center justify-center text-center"))
    end
    nil
  end
end
