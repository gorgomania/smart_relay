// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
//= require jquery
import "@hotwired/turbo-rails"
import "jquery"

window.jQuery = window.$ = $

document.addEventListener("turbo:load", function() {
  // Прыжок label при focus
  $(document).on("focus.auth", ".auth_input", function() {
    let $label;
    
    if ($(this).parent().hasClass("field")) {
      $label = $(this).prev();
    } else if ($(this).parent().prev().hasClass("auth_label")) {
      $label = $(this).parent().prev();
    } else {
      $label = $(this).parent().prev().children();
    }
    
    $label.animate({ "top": "22px" }, 250).css("font-size", "13px");
  });

  // Прыжок label при blur
  $(document).on("blur.auth", ".auth_input", function() {
    if (!this.value) {
      let $label;
      
      if ($(this).parent().hasClass("field")) {
        $label = $(this).prev();
      } else if ($(this).parent().prev().hasClass("auth_label")) {
        $label = $(this).parent().prev();
      } else {
        $label = $(this).parent().prev().children();
      }
      
      $label.animate({ "top": "42px" }, 250).css("font-size", "16px");
    }
  });
});

