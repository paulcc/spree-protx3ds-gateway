# based on COMMIT?
module Spree::Protx3dsCheckout
  include ERB::Util

  # destination for gateway callbacks
  def callback_host
    if ActiveMerchant::Billing::Base.gateway_mode == :test
      File.read("which_test_host").chomp 
    else
      request.host
    end
  end 

  def checkout
    build_object 
    load_object 
    load_data
    load_checkout_steps                                             

    if request.get?                     # default values needed for GET / first pass
      @order.bill_address ||= Address.new(:country => @default_country)
      @order.ship_address ||= Address.new(:country => @default_country) 

      if @order.creditcards[0].nil?
        @order.creditcards[0] = Creditcard.new(:month => Date.today.month, :year => Date.today.year)
      end
    end

    unless request.get?                 # the proper processing
      @method_id = params[:method_id]

      # push the current record ids into the incoming params to allow nested_attribs to do update-in-place
      if @order.bill_address && params[:order][:bill_address_attributes]
        params[:order][:bill_address_attributes][:id] = @order.bill_address.id 
      end
      if @order.ship_address && params[:order][:ship_address_attributes]
        params[:order][:ship_address_attributes][:id] = @order.ship_address.id 
      end

      tmp_cc_attributes = params[:order][:creditcards_attributes]["0"]
      params[:order].delete :creditcards_attributes


      # and now do the over-write, saving any new changes as we go
      @order.update_attributes(params[:order])
    
      @order.shipments.clear
      @order.shipments.build(:address => @order.ship_address, 
                             :shipping_method => ShippingMethod.find_by_id(@method_id) || ShippingMethod.first)

      # set some derived information
      @order.user = current_user       
      @order.email = current_user.email if @order.email.blank? && current_user
      @order.ip_address = request.env['REMOTE_ADDR']
      @order.update_totals unless 

      begin
        # need to check valid b/c we dump the creditcard info while saving
        if @order.valid?                       
          if params[:final_answer].blank?
            @order.save
          else                                           
            # now fetch the CC info and do the authorization
            @order.creditcards.destroy_all
            @order.creditcards[0] = Creditcard.new tmp_cc_attributes
            @order.creditcards[0].use_3ds = true
            @order.creditcards[0].address = @order.bill_address 
            @order.creditcards[0].order = @order
            @order.creditcards[0].valid? || raise(@order.creditcards[0].errors)

            (@order.vtx_code ||= @order.number + '\x60').succ!
            result = @order.creditcards[0].authorize(@order.total, :order_id => @order.vtx_code)



            if result.is_a?(CreditcardTxn) 
              @order.complete # implies save?
              # remove the order from the session
              session[:order_id] = nil 
            elsif result.is_a?(Proc)
              @order.save                       # and save what we have
              callback = request.protocol + callback_host + "/orders/#{@order.number}/callback_3dsecure?authenticity_token=#{url_encode form_authenticity_token}"
              @form = result.call(callback, '<input type="submit" value="' + t("click_to_begin_3d_secure_verification") + '">') 
              render :action => '3dsecure_verification' and return
            end

          end
        else
          flash.now[:error] = t("unable_to_save_order")  
          render :action => "checkout" and return unless request.xhr?
        end       
      rescue Spree::GatewayError => ge
        flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
        render :action => "checkout" and return 
      end
      

      respond_to do |format|
        format.html do  
          flash[:notice] = t('order_processed_successfully')
          order_params = {:checkout_complete => true}
          order_params[:order_token] = @order.token unless @order.user
          redirect_to order_url(@order, order_params)
        end
        format.js {render :json => { :order_total => number_to_currency(@order.total), 
                                     :ship_amount => number_to_currency(@order.ship_amount), 
                                     :tax_amount => number_to_currency(@order.tax_amount),
                                     :available_methods => rate_hash}.to_json,
                          :layout => false}
      end
      
    end
  end
  
  def load_checkout_steps
    @checkout_steps = %w{registration billing shipping shipping_method payment confirmation}
    @checkout_steps.delete "registration" if current_user
  end  


  ## 3ds specifics
  ## 

  def callback_3dsecure
    @callback = request.protocol + callback_host + "/orders/#{params[:id]}/complete_3dsecure"
    render :action => "callback_3dsecure", :layout => false
  end

  def complete_3dsecure
    order = Order.find_by_number(params[:id])
    begin
      ActiveRecord::Base.transaction do
        # pass confirmation codes back to gateway, and fill in response code
        # NOTE: completion does NOT require valid CC details
        order.creditcards[0].complete_3dsecure(params)
        order.complete
        session[:order_id] = nil if order.checkout_complete  
      end
      respond_to do |format|
        format.html {redirect_to order_url(order, :checkout_complete => true)}
      end
    rescue Spree::GatewayError => ge
      flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
      render :action => "checkout" and return 
    end
  end
end
