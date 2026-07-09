Rails.application.routes.draw do
  get "auth", to: "yandex_auth#index", as: :yandex_auth
  get "auth/yandex/login", to: "yandex_auth#login", as: :yandex_login
  get "auth/yandex/callback", to: "yandex_auth#callback", as: :yandex_callback
  delete "auth/yandex/logout", to: "yandex_auth#logout", as: :yandex_logout
  resources :relays, only: [ :index ] do
    member do
      post :turn_on
      post :turn_off
    end
  end
  root "relays#index"
end
