class AddCurrencyFieldToShops < ActiveRecord::Migration[5.2]
  def change
    add_column :shops, :currency, :string
    add_column :shops, :currency_symbol, :string
  end
end
