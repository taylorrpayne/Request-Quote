class OrdersController < ApplicationController
 	protect_from_forgery with: :null_session

 	def create_draft_order

 		puts "==========#{params[:customer_details].inspect}"
 		puts "**********#{params[:customer_details][:email]}"
 		@customer_details = params[:customer_details]

		@is_draft_order = 0
		@store_id = params[:store_id]
		@store = Shop.find_by_shopify_domain(@store_id)
		puts @store.inspect
		ShopifyAPI::Base.site = "https://#{ShopifyApp.configuration.api_key}:#{@store.shopify_token}@#{@store_id}/admin"
		@customer = ShopifyAPI::Customer.search(query: "email:#{@customer_details[:email]}")
		unless @customer.present?
			puts "------======customer not present"
			@customer = ShopifyAPI::Customer.create(email: "#{@customer_details[:email]}",first_name: "#{@customer_details[:first_name]}",last_name: "#{@customer_details[:last_name]}")
	    @customer_id = @customer.id rescue nil
	    if @customer.valid?
        @customer.send_invite
	    end
		else
			puts "------======customer present"
			@customer_id = @customer.first.id rescue nil
		end
		puts "Customer Id===#{@customer_id}"
		
		if @store.present?
		  @currency_symbol = @store.currency_symbol
		  @currency_symbol = '$'
		  @cart_json = JSON.parse(params[:cart_json])
		  @note = @cart_json['cart']['note']
		  @attributes = @cart_json['cart']['attributes']
		  @note_attributes = []
		  if @attributes.present?
		    @attributes.each do |key,attr|
		      @note_attributes.push({"name": key,"value": attr})
		    end
		  end
		  @items = @cart_json['cart']['items']
		  @product_count_array = {}
		  @new_cart_array = []
		  @items.each do |item| 
		    @quantity = 0 
		    @items.each do |item1|
		      if item['product_id'] == item1['product_id']
		        @quantity = @quantity + item1['quantity'].to_i
		      end
		    end
		    if !@product_count_array.key?(item['product_id'])
		      @product_count_array[item['product_id']]=@quantity
		    end
		  end 

		  @items.each do |item|
		    @line_item = {}
		    @pid = item['product_id']
		    @pqty = item['quantity']
		    @pprice = (item['price'].to_f/100)  
		    @plineprice = (item['line_price'].to_f/100)
		    @line_item['variant_id'] = item['variant_id']
		    @line_item['price'] = @pprice.to_s
		    @line_item['quantity'] = @pqty
		    @properties = item['properties']
		    @pproperties_array = []

		    if @properties.present?
		      @pproperties_array=[]
		      @currency_flag = 0
		      @properties.each do |key,val|
		        if val.present?
		          @aa={
		            "name": key,
		            "value": val
		          }
		        	@pproperties_array.push(@aa)
		          if val.include?(@currency_symbol)
		            @currency_flag = 1
		          end
		        end
		      end
		    end
		    if @currency_flag == 0
		      @line_item['properties'] = @pproperties_array
		    end
		    @new_cart_array.push(@line_item)
		    @properties=item['properties']
		    @p_title = "Customization Cost For #{item['title']}"
		    @pprice = 0.00

		    if @properties.present? 
		      url = URI("https://productoption.hulkapps.com/store/get_cart_details_api")
		      http = Net::HTTP.new(url.host, url.port)
		      http.use_ssl = true
		      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		      request = Net::HTTP::Post.new(url)
		      request["content-type"] = 'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW'
		      request["cache-control"] = 'no-cache'
		      request.body = "------WebKitFormBoundary7MA4YWxkTrZu0gW\r\nContent-Disposition: form-data; name=\"store_id\"\r\n\r\n#{@store_id}\r\n------WebKitFormBoundary7MA4YWxkTrZu0gW\r\nContent-Disposition: form-data; name=\"pid\"\r\n\r\n#{item['product_id']}\r\n------WebKitFormBoundary7MA4YWxkTrZu0gW--"
		      response = http.request(request)
		      @options_all = JSON.parse(response.read_body)
		      @properties.each do |key,val|
		        if @options_all.to_h[key].present?
		          @option_type = @options_all[key]['option_type']
		          if((@option_type == 'textbox' || @option_type == 'textarea') && val.present?)
		            @pp = @options_all[key]['none']
		            @pprice = @pprice + @pp.to_f
		          elsif(@option_type != 'file_upload')
		            val.split(',').each do |v|
		                @op_val = v.split("[").first.strip
		                @pp = @options_all[key][@op_val]
		                @pprice = @pprice + @pp.to_f
		            end
		          end  
		        end
		      end
		    end

		    @line_item = {}
		    @line_item['title']= @p_title.to_s
		    @line_item['price'] = (@pprice*100).round / 100.0
		    @line_item['quantity']= @pqty
		    @line_item['properties'] = @pproperties_array
		    if @pprice > 0
		      @new_cart_array.push(@line_item) 
		      @is_draft_order = 1
		    end
		  end
		  puts "==============new_cart_array #{@new_cart_array.inspect}"
		  
		    @draftorder = ShopifyAPI::DraftOrder.create({
	        line_items: @new_cart_array,
	        note: @note,
	        note_attributes: @note_attributes,
	        customer: {
			      "id": @customer_id
			    },
			    shipping_address: {
					  "address1": @customer_details[:address1],
					  "address2": @customer_details[:address2],
					  "city": @customer_details[:city],
					  "country": @customer_details[:country],
					  "first_name": @customer_details[:first_name],
					  "last_name": @customer_details[:last_name],
					  "province": @customer_details[:province],
					  "zip": @customer_details[:zip],
					  "company": @customer_details[:company]
					  # "country_code": "CA",
					  # "province_code": "ON"
					}
			    # shipping_address: {
					  # "address1": "123 Amoebobacterieae St",
					  # "address2": "test",
					  # "city": "Ottawa",
					  # "country": "Canada",
					  # "first_name": "Bob",
					  # "last_name": "Bobsen",
					  # "province": "Ontario",
					  # "zip": "K2P0V6",
					  # "country_code": "CA",
					  # "province_code": "ON"
					# }
		    })
		    puts "================RESPONSEEEEEEEE==#{@draftorder.inspect}"
		    if @draftorder.present?

		    	# Customer Mail
		    	@to = @customer_details[:email].strip
					@first_name = @customer_details[:first_name].strip
					@subject = "Thanks for submitting your quote, #{@first_name}!"
					OrderMailer.customer_mail(@subject,@to,@first_name).deliver

					#Admin Mail
					@subject = "New Quote Request #{@draftorder.id}"
					@to = 'piyush@planetx.in'
					OrderMailer.admin_mail(@subject,@to,@draftorder,@store.shopify_domain,@store.currency_symbol).deliver

		      render plain: @draftorder.invoice_url rescue '/checkout'
		    else
		      render plain: "error"
		    end

		else
		  render plain: '/checkout'
		end
	end

	def test
		#admin mail
		ShopifyAPI::Base.site = "https://b05427f38f486782a8b9a94f1c81e6dc:f8c037dbe5cc9cb08d8eccb1dcdc29dd@demo-productoption.myshopify.com/admin"
		@draft_order = ShopifyAPI::DraftOrder.find(67603005482)
		@subject = "New Quote Request #{@draft_order.id}"
		@to = 'piyush@planetx.in'
		@store_name = "demo-productoption.myshopify.com"
		@currency_symbol = '$'
		OrderMailer.admin_mail(@subject,@to,@draft_order,@store_name,@currency_symbol).deliver
		# render json: @draft_order.shipping_address.address1 and return











		# @from = 'bill@miataroadster.com'
		# @to = 'piyush@planetx.in'
		# @first_name = "Piyush"
		# @subject = "Thanks for submitting your quote, #{@first_name}!"
		# OrderMailer.customer_mail(@subject,@to,@first_name).deliver
		# render plain: "send"
		# ShopifyAPI::Base.site = "https://501cb634e80ebb00c7146913c67fce4c:18ad5998c0b6bc4913c5a022ff472fd0@demo-helly.myshopify.com/admin"

		# @customer = ShopifyAPI::Customer.search(query: "email:krunal@planetx.in")
		# unless @customer.present?
		# 	@customer = ShopifyAPI::Customer.create(email: 'krunal@planetx.in',first_name: '',last_name:'')
	 #    @customer_id = @customer.id rescue nil
	 #    if @customer.valid?
  #       @customer.send_invite
  #       @is_mail_sent = true
	 #    end
		# else
		# 	@customer_id = @customer.first.id rescue nil
		# end
		# render json: @customer_id and return


	end
end
