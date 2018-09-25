class Shop < ActiveRecord::Base
  include ShopifyApp::SessionStorage
  after_create :set_configuration
  after_update :set_configuration

  def set_configuration
  	puts "here==========="
    ShopifyAPI::Base.site = "https://#{ShopifyApp.configuration.api_key}:#{self.shopify_token}@#{self.shopify_domain}/admin/"
    @current_store = ShopifyAPI::Shop.current
    @store_id = @current_store.myshopify_domain 
    puts "@store_id===#{@store_id}"
    @store = Shop.find_by_shopify_domain(@store_id)
    unless @store.currency_symbol.present? && @store.currency.present?
  		currency_symbol = Money::Currency.new(@current_store.currency).symbol        
  		@store.update(currency_symbol: currency_symbol,currency: @current_store.currency)
  	end
  end

end
