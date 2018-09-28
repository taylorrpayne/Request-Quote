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

            $('#form .popup-btn').on('click',function(e){
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
                    $('.action_bottom_submit .action_button').html('Submit').prop('disabled', false);
                    $('body .request-quote-success-msg').html('<a href=\"javascript:void(0);\" class=\"close\" data-dismiss=\"alert\" aria-label=\"close\" title=\"close\">×</a>Thanks for submitting your quote! We’ll be in touch within the next 24 hours as we work on finding the best shipping rates to get your products to you. If you need any immediate assistance please contact us.').show('slow');
                    $('body').trigger('click');
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
          clear: both;
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
          color: #fff;
          border: 1px solid #ff8683;
        }
        .request-quote-wrapper label{
          display: block;
          font-weight: bold;
          font-size: 13px;
          text-align: left;
          margin-bottom: 5px;
          text-transform: uppercase;
        }
        
        .request-quote-wrapper input[type=\"text\"], .request-quote-wrapper input[type=\"password\"], .request-quote-wrapper input[type=\"email\"]{
          display: block;
          width: 100%;
          height: 44px;
          min-height: 44px;
          padding: 0 10px;
          margin: 0;
          line-height: 22px;
          border: 1px solid #c3c3c3;
          outline: none;
          background: #fff;
          color: #5f6a7d;
          font: 13px \"HelveticaNeue-Light\", \"Helvetica Neue Light\", \"Helvetica Neue\", Helvetica, Arial, sans-serif;
          margin-bottom: 15px;
          -webkit-appearance: none;
          text-rendering: optimizeLegibility;
          -webkit-font-smoothing: antialiased;
          -moz-osx-font-smoothing: grayscale;
        }

        #address_province_container_new{
            clear: both;
        }
        
        #address_province_container_new select{
          width: 100%;
          margin-bottom: 15px;
        }

        .request-quote-success-msg{
          background-color: #c7f1c7;
          position: relative;
          padding: 15px 25px;
          border-radius: 6px;
          font-size: 16px;
          display: none;
          width: 60%;
          margin: 0 auto;
        }  
        .request-quote-success-msg a{
          position: absolute;
          top: 0;
          font-size: 30px;
          right: 5px;
        }

      </style>",theme_id: @theme.id)
  end

end
