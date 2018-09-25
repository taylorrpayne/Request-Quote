Rails.application.routes.draw do
  post 'orders/create_draft_order'
  get 'orders/test'
  root :to => 'home#index'
  mount ShopifyApp::Engine, at: '/'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
