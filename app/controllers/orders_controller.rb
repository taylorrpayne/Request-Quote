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
		  @note = @cart_json['cart']['note'] rescue nil
		  @attributes = @cart_json['cart']['attributes'] rescue nil
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

	def add_assets
		ShopifyAPI::Base.site = "https://14e6bde8c42dd6f5b210dca5dde5c4d8:e717bfa6cd4149b3d01cd517204fd655@miataroadsteroffical.myshopify.com/admin/"
		@theme = ShopifyAPI::Theme.find(:all).where(role: 'main').first
		@asset = ShopifyAPI::Asset.find('layout/theme.liquid', :params => { theme_id: @theme.id})
    @asset_value = @asset.value
    @update = @asset.update_attributes(theme_id: @theme.id,value: @asset_value.gsub("</body>","{% include 'request-quote' %}</body>")) unless @asset_value.include?("{% include 'request-quote' %}")

  	@asset = ShopifyAPI::Asset.create(key: 'snippets/request-quote.liquid', value: "{{ \"shopify_common.js\"  | shopify_asset_url | script_tag }}
			{{ \"customer_area.js\"  | shopify_asset_url | script_tag }}

			<div class=\"request-quote-wrapper\">
			  <div class=\"inner-wrapper\">
			    <div class=\"close-popup\">
			      <a class=\"close\" href=\"javascript:void(0);\"></a>
			    </div>
		     	<div class=\"error\"><p>Please select a country.</p></div>      
		     	<form class=\"request-quote-form\" action=\"\" method=\"post\">
		    	  <div id=\"first_name\" class=\"input-field common-field\">
	            <label for=\"first_name\" class=\"login\">{{ 'customer.register.first_name' | t }}</label>
	            <input type=\"text\" value=\"\" id=\"first_name\" class=\"large\" size=\"30\" name=\"{{ 'customer.register.first_name' | t }}\" />           
		        </div>
	          <div id=\"last_name\" class=\"input-field common-field\">
	            <label for=\"last_name\" class=\"login\">{{ 'customer.register.last_name' | t }}</label>
	            <input type=\"text\" value=\"\" id=\"last_name\" class=\"large\" size=\"30\" name=\"{{ 'customer.register.last_name' | t }}\" />
	          </div>
	          <div id=\"email\" class=\"email-field common-field\">
	            <label for=\"email\" class=\"login\">{{ 'customer.register.email' | t }}</label>
	            <input type=\"email\" value=\"\" id=\"email\" class=\"large\" size=\"30\" name=\"{{ 'customer.register.email' | t }}\"  />
	          </div>
	          <h4 id=\"add_address_title\">SHIPPING ADDRESS</h4>
			      <div class=\"shipping-address\">
		          <div class=\"input-field common-field\">
		            <label for=\"address_company_new\">{{ 'customer.addresses.company' | t }}</label>
		            <input type=\"text\" id=\"address_company_new\" class=\"address_form\" value=\"\" autocapitalize=\"words\" name=\"{{ 'customer.addresses.company' | t }}\" >
		          </div>

		          <div class=\"input-field common-field\">
		            <label for=\"address_address1_new\">Address</label>
		            <input type=\"text\" id=\"address_address1_new\" class=\"address_form\" value=\"\" autocapitalize=\"words\" name=\"Address\" >
		          </div>

		      	  <div class=\"input-field common-field\">
	              <label for=\"address_city_new\">{{ 'customer.addresses.city' | t }}</label>
	              <input type=\"text\" id=\"address_city_new\" class=\"address_form\" value=\"\" autocapitalize=\"words\" name=\"{{ 'customer.addresses.city' | t }}\" >
	            </div>

	            <div class=\"input-field address-select\">
	              <label for=\"address_country_new\">{{ 'customer.addresses.country' | t }}</label>
	              <select id=\"address_country_new\"  data-default=\"{{form.country}}\" >{{ country_option_tags }}</select>
	            </div>

	            <div id=\"address_province_container_new\" class=\"state-field address-select\" style=\"display:none\">
	              <label for=\"address_province_new\">{{ 'customer.addresses.province' | t }}</label>
	              <select id=\"address_province_new\" class=\"address_form\" data-default=\"{{form.province}}\" ></select>
	            </div>

		          <div class=\"input-field common-field\">
	              <label for=\"address_zip_new\">{{ 'customer.addresses.zip' | t }}</label>
	              <input type=\"text\" id=\"address_zip_new\" class=\"address_form\"  value=\"\" autocapitalize=\"characters\" name=\"{{ 'customer.addresses.zip' | t }}\" >
		          </div>

	            <div class=\"input-field common-field\">
	              <label for=\"address_phone_new\">{{ 'customer.addresses.phone' | t }}</label>
	              <input type=\"tel\" id=\"address_phone_new\" class=\"address_form\" value=\"\" name=\"{{ 'customer.addresses.phone' | t }}\" >
	            </div>
			      </div>
	          <div class=\"action_bottom_submit\">
	            <button class=\"btn action_button\" type=\"submit\">Submit</button>         
	          </div>	
		    	</form>
			  </div>
			</div>

			<script>
			    $(window).on('load',function(){
			  
			      $('.request-quote-wrapper .close-popup').on('click',function(){    	
			        $('body').trigger('click');
			      }); 

			      $('#cart_form .popup-btn').on('click',function(e){
			        e.stopPropagation();        
			        $('.request-quote-wrapper').addClass('active');
			        $('body').addClass('popup-open');
			        $('.request-quote-wrapper .inner-wrapper .error').html('');      
			        $('.request-quote-wrapper .inner-wrapper form #address_country_new')      
			        .eq(0)
			        .val('---')
			        .trigger('change');        
			        $('.request-quote-wrapper .inner-wrapper form .common-field').find('input').val('');      
			      });

			      $('.request-quote-wrapper .inner-wrapper').on('click',function(e){
			        e.stopPropagation();
			      });

			      $('body').on('click',function(){
			        $('.request-quote-wrapper').removeClass('active');
			        $('body').removeClass('popup-open');
			      });
			      
			       function validatePhone(getPhone){      	
			         var filter = /^[0-9-+]+$/;
			         if (filter.test(getPhone)) {
			           $('.request-quote-form .common-field input[type=tel]').removeClass('error-field');
			           return true;
			         }
			         else {
			            $('.request-quote-form .common-field input[type=tel]').addClass('error-field');
			           return false;
			         }
			      }
			      
			      function validateEmail(getEmail) {
			        var filter = /^([\\w-\\.]+)@((\\[[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.)|(([\\w-]+\\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\\]?)$/;
			        if (filter.test(getEmail)) {
			            $('.request-quote-form .common-field input[type=email]').removeClass('error-field');
			          return true;
			        }
			        else {
			          $('.request-quote-form .common-field input[type=email]').addClass('error-field');
			          return false;
			        }
			      }

			      
			      
			      $('.request-quote-form .action_bottom_submit .action_button').on('click',function(e){        
			        e.preventDefault();
			        // loader       
			         $('body .request-quote-success-msg').html('').hide();
			      	var country = $(this).closest('form').find('#address_country_new').val();
			         $(this).closest('.inner-wrapper').find('.error').removeClass('active');
					var phone,email,firstName,lastName,city,province,zipcode,company,address,customerObj;
			        if(country == '---' ){                    
			          $(this).closest('form').find('#address_country_new').addClass('error-field');
			        }else{           
			          $(this).closest('form').find('#address_country_new').removeClass('error-field');
			        }
			                        
			        $('.request-quote-form .common-field').each(function(){
			        	var $this = $(this);
			            if($this.find('input[type=tel]').length > 0){
			              phone = $this.find('input[type=tel]').val();             
			              $this.find('input').removeClass('error-field');
			              if(phone.length > 0){                
			              	validatePhone(phone);
			              }else{
			              	$this.find('input').addClass('error-field');
			              }
			            }else if($this.find('input[type=email]').length > 0){
			              email = $this.find('input[type=email]').val();
			              $this.find('input').removeClass('error-field');
			              if(email.length > 0){                
			                validateEmail(email);
			              }else{
			                $this.find('input').addClass('error-field');
			              }
			            }else{
			              var inputVal = $this.find('input').val();
			              if(inputVal.length == 0){
			              	$this.find('input').addClass('error-field');
			              }else{
			              	$this.find('input').removeClass('error-field');
			              }
			            }
			                
			        });
			         
			        firstName = $(this).closest('form').find('input#first_name').val();
			        lastName = $(this).closest('form').find('input#last_name').val();
			        city = $(this).closest('form').find('#address_city_new').val();
			        province = $(this).closest('form').find('#address_province_new').val();
			        company = $(this).closest('form').find('#address_company_new').val();
			        zipcode = $(this).closest('form').find('#address_zip_new').val();
			        address = $(this).closest('form').find('#address_address1_new').val();
			        
			        if(firstName != '' && lastName != '' && city != '' && province!= '' && company != '' && zipcode != '' && country != '' && city != '' && phone!= '' && email != '' && address != '' ){          
			           $(this).html('Loading...');
			          customerObj = {
			            first_name : firstName,
			            last_name : lastName,
			            email : email,
			            company : company,
			            address1 : address,
			            city : city,
			            country : country,
			            province : province,
			            zip : zipcode,
			            phone : phone
			          }
			          $.ajax({
			            type: \"POST\",
			            url: \"https://requestaquoteapp.com/orders/create_draft_order\",
			            data: {cart_json: JSON.stringify(window.hulkapps),store_id: window.hulkapps.store_id,customer_details:customerObj},
			            crossDomain: true,
			            success: function(res) {
			              alert(res);
			              $(this).html('Submit');
			          	$('body .request-quote-success-msg').html('<a href=\"javascript:void(0);\" class=\"close\" data-dismiss=\"alert\" aria-label=\"close\" title=\"close\">×</a><p>Thanks for submitting your quote! We’ll be in touch within the next 24 hours as we work on finding the best shipping rates to get your products to you. If you need any immediate assistance please contact us.</p>').show('slow');
			       		 $(this).closest('body').trigger('click');
			            },
			            error: function(){
			       		 $('body .request-quote-success-msg').html('').hide('slow');
			            }
			          });
			          
			          console.log(customerObj);
			          console.log(window.hulkapps);
			          console.log(JSON.stringify(window.hulkapps));
			        }
			      });
			      
			     
			      
			    });
			  $(document).ready(function(){        
			    // Initiate provinces for the New Address form
			    new Shopify.CountryProvinceSelector('address_country_new', 'address_province_new', {hideElement: 'address_province_container_new'});

			    // Initiate provinces for all existing addresses
			    {% for address in customer.addresses %}
			    new Shopify.CountryProvinceSelector('address_country_{{address.id}}', 'address_province_{{address.id}}', {hideElement: 'address_province_container_{{address.id}}'});
			  {% endfor %}    

			    $('body').on('click','.request-quote-success-msg .close',function(){
			    	$(this).closest('.request-quote-success-msg').hide();
			    });
			  });
			</script>

			<style>
				.request-quote-wrapper{	 
				  position: fixed; 
				  top: 0;
				  left:0;
				  z-index: 99;
				  width: 100%;
				  height: 100%;
				  background-color: rgba(0, 0, 0, 0.7);
				  display: none;
				}
				.request-quote-wrapper .inner-wrapper{
				    position: fixed;
				    top: 50%;
				    left: 50%;
				    transform: translate(-50%,-50%);  	
				    padding: 20px;
				    height: auto;
				    overflow-y: scroll;
				    background: #FFFFFF ;
				    border: 1px solid #000;    
				    width: 600px; 
				}  
				.request-quote-wrapper.active{
				  	display: block;
				}  
				.request-quote-wrapper .error{
				      color: red;
				      display: none;
				}    
				.request-quote-wrapper .request-quote-form{      
				  margin: 20px -10px;
				}  
				.request-quote-form .action_bottom_submit{
				  text-align: center;
				  cursor: pointer;
				}  
				.request-quote-form  .action_button{
				    outline: none;
				}
				.request-quote-form::after{
				  clear: both;
				  content: '';
				  display: block;
				}  
				.request-quote-wrapper .error.active{
				  display: block;
				}

				.request-quote-wrapper .close-popup{
				    position: absolute;
				    top: 10px;
				    right: 40px;
				    cursor: pointer; 
				}
				.request-quote-wrapper .close { 
				  width: 26px;
				  height: 26px;  
				}
				.request-quote-wrapper .close:hover {
				  opacity: 1;
				}
				.request-quote-wrapper .close:before, .request-quote-wrapper .close:after {
				  position: absolute;
				  left: 15px;
				  content: ' ';
				  height: 22px;
				  width: 2px;
				  background-color: #000;
				}
				.request-quote-wrapper .close:before {
				  transform: rotate(45deg);
				}
				.request-quote-wrapper .close:after {
				  transform: rotate(-45deg);
				}
				.request-quote-wrapper .error-field{
					border: 1px solid red !important;
				}
				body.popup-open{
				  overflow: hidden;
				  position: fixed;
				  height: 100%;
				  width: 100%;
				}    
				.success-msg{
				  color: #3c763d;
				  background-color: #dff0d8;
				  border-color: #d6e9c6;
				  position: relative;
				  padding: 15px 20px 15px 15px; 
				}  
				.success-msg p{
				    margin-bottom: 0;
				    margin-right: 10px;
				}  
				.success-msg .close {
				  position: absolute;
				  top: 10px;
				  right: 10px;
				  color: inherit;
				  float: right;
				  font-size: 40px;
				}  

				@media only screen and (min-width: 768px){
				  .request-quote-wrapper .input-field, .request-quote-wrapper .address-field{
				    display: inline-block;
				    width: 50%;
				    float: left; 
				  }
				  .request-quote-form .input-field, .request-quote-form .email-field, .request-quote-form .address-field, .request-quote-form #address_province_container_new{
				  	 padding: 0 10px;
				  }
				}
				  

				@media only screen and (min-width: 481px) and (max-width: 767px){
					.request-quote-wrapper .inner-wrapper{
				      width: 450px;
				      height: 600px;
				    }
				}  
				  
				@media only screen and (max-width: 481px){
				  .request-quote-wrapper .inner-wrapper{
				    width: 300px;
				    height: 600px;
				  }
				}   
			  .action_bottom_submit .action_button,.popup-btn{
	        background: #ff0c04;
	        color: #ffffff;
	        border: 1px solid #ff0c04;
	        padding: 0 20px;
	        text-align: center;
	        cursor: pointer;
	        min-height: 44px;
	        height: 40px;
	        line-height: 1.2;
	        vertical-align: top;
	        font-weight: normal;
	        font-size: 14px;
	        text-transform: uppercase;
	        letter-spacing: 0px;
	        display: -webkit-inline-box;
	        display: -webkit-inline-flex;
	        display: -moz-inline-flex;
	        display: -ms-inline-flexbox;
	        display: inline-flex;
	        -webkit-align-items: center;
	        -moz-align-items: center;
	        -ms-align-items: center;
	        align-items: center;
	        -webkit-justify-content: center;
	        -moz-justify-content: center;
	        -ms-justify-content: center;
	        justify-content: center;
	        -ms-flex-pack: center;
	        transition: all 0.2s linear;
	        -webkit-appearance: none;
	        -webkit-font-smoothing: antialiased;
	        -moz-osx-font-smoothing: grayscale;
	        font-smoothing: antialiased;
	        border-radius: 0;
	      }
	      .action_bottom_submit .action_button:hover,.popup-btn:hover{
	      	background: #ff8683;
					border: 1px solid #ff8683;
	      }
			</style>",theme_id: @theme.id)
		render json: @asset and return
	end
end
