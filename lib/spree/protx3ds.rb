# Adapted for protx3ds
module Spree::Protx3ds
  include ERB::Util
  include Spree::PaymentGateway

  ssl_required :complete_3dsecure, :callback_3dsecure


  # this is based on a buggy version - prefer to update some time.
  def checkout
    build_object 
    load_object 
    load_data
    load_checkout_steps                                             
    
    @order.update_attributes(params[:order])

    # additional default values needed for checkout
    @order.bill_address ||= Address.new(:country => @default_country)
    @order.ship_address ||= Address.new(:country => @default_country)
    if @order.creditcards.empty?
      @order.creditcards.build(:month => Date.today.month, :year => Date.today.year)
    end
    @shipping_method = ShippingMethod.find_by_id(params[:method_id]) if params[:method_id]  
    @shipping_method ||= @order.shipping_methods.first    
    @order.shipments.build(:address => @order.ship_address, :shipping_method => @shipping_method) if @order.shipments.empty?    

    if request.post?                           
      #@order.creditcards.clear
      #@order.attributes = params[:order]  # duplic as above??
      @order.creditcards[0].address = @order.bill_address if @order.creditcards.present? # lu present
      @order.user = current_user       
      @order.ip_address = request.env['REMOTE_ADDR']
      @order.update_totals    # tax / ship etc

      begin
        # need to check valid b/c we dump the creditcard info while saving
        if @order.valid?                       
          if params[:final_answer].blank?
            @order.save
          else                                           
            
            tmp_order_code = @order.number + '_' + Time.now.min.to_s + Time.now.sec.to_s
            result = @order.creditcards[0].authorize(@order.total, :order_id => tmp_order_code)

            if result.is_a?(CreditcardTxn) 
              @order.complete # implies save?
              # remove the order from the session
              session[:order_id] = nil 
            elsif result.is_a?(Proc)
              @order.number = tmp_order_code	# save code used this time
              @order.save                       # and save what we have
              callback = request.protocol + request.host + "/orders/#{@order.number}/callback_3dsecure?authenticity_token=#{url_encode form_authenticity_token}"
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
          ## disabled ## flash[:notice] = t('order_processed_successfully')
          order_params = {:checkout_complete => true}
          order_params[:order_token] = @order.token unless @order.user
          redirect_to order_url(@order, order_params)
        end
        format.js {render :json => { :order => {:order_total => @order.total, 
                                                :ship_amount => @order.ship_amount, 
                                                :tax_amount => @order.tax_amount},
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
  # done via class_eval - have to?
  # ssl_required :show, :checkout, :complete_3dsecure, :callback_3dsecure, :secure_form
  # protect_from_forgery :except => :callback_3dsecure

  def callback_3dsecure
    @callback = request.protocol + request.host + "/orders/#{params[:id]}/complete_3dsecure"
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
