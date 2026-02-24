module ApplicationHelper
  def flash_messages
    flash.each do |type, msg|
      if type == "notice"
        concat(content_tag(:div, class: "mt-5 px-3 h-16 w-full border border-[#0a9130] text-[#0a9130] bg-[#a0e7b1] rounded-lg flex items-center justify-center") do
          msg
        end)
      else
        concat(content_tag(:div, class: "mt-5 px-3 h-16 w-full border border-red-800 text-red-800 bg-red-200 rounded-lg flex items-center justify-center text-center") do
          msg
        end)
      end
    end
    nil
  end
end
