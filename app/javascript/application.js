import "@hotwired/turbo-rails"
import "jquery"

function findLabel($input) {
  if ($input.parent().hasClass("field")) return $input.prev();
  if ($input.parent().prev().hasClass("auth_label")) return $input.parent().prev();
  return $input.parent().prev().children();
}

$(document).on("focus.auth", ".auth_input", function() {
  findLabel($(this)).animate({ "top": "22px" }, 250).css("font-size", "13px");
});

$(document).on("blur.auth", ".auth_input", function() {
  if (!this.value) {
    findLabel($(this)).animate({ "top": "42px" }, 250).css("font-size", "16px");
  }
});

