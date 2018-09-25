ShopifyApp.configure do |config|
  config.application_name = "My Shopify App"
  config.api_key = ENV['SHOPIFY_APP_API_KEY']
  config.secret = ENV['SHOPIFY_APP_API_SECREAT']
  config.scope = "write_products, write_draft_orders, write_customers"
  config.embedded_app = true
  config.after_authenticate_job = false
  config.session_repository = Shop
  config.webhooks = [
    {topic: 'draft_orders/create', address: "ENV['APP_DOMAIN']/webhooks/draft_orders_create", format: 'json'},
  ]
end
