Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "auth/yandex/login", to: "yandex_auth#login", as: :yandex_login
  get "auth/yandex/callback", to: "yandex_auth#callback", as: :yandex_callback
  resources :button, only: [ :index ] do
    member do
      post :turn_on
      post :turn_off
    end
  end

  root "button#index"
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
