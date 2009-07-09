class CheckoutsController < Spree::BaseController 
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  before_filter :load_data
  
  resource_controller :singleton
  belongs_to :order             
  
  layout 'application'   

  # alias original r_c method so we can handle special gateway exception that might be thrown
  alias :rc_update :update
  def update 
    begin
      rc_update	# to load/save everything else

      # if process_creditcard?
      if @order and @checkout.creditcard and not @checkout.creditcard[:number].blank?

        @order.vtx_code = @order.number + "-0" if @order.vtx_code.nil?
        @order.update_attribute(:vtx_code, @order.vtx_code.succ)

        cc = Creditcard.new(@checkout.creditcard.merge(:address => @checkout.bill_address, :checkout => @checkout))
        cc.valid?	# ONLY to call prepare...
        result = cc.authorize(@order.total, :order_id => @order.vtx_code)
        cc.save!
      else
        # nothing
      end

      respond_to do |format|
        format.html do
          flash = {}

          if result.is_a?(CreditcardTxn) 
            @order.complete 
            flash[:notice] = t('order_processed_successfully')
            order_params = {:checkout_complete => true}
            order_params[:order_token] = @order.token unless @order.user
            session[:order_id] = nil if @order.checkout.completed_at
            redirect_to order_url(@order, order_params) and next if params[:final_answer]

          elsif result.is_a?(Proc)
            @order.save                       # and save what we have

            # callback = request.protocol + request.host_with_port + "/orders/#{order.number}/checkout/callback_3dsecure?authenticity_token=#{url_encode form_authenticity_token}"
            callback = callback_3dsecure_order_checkout_url(@order) + "?authenticity_token=#{form_authenticity_token}" ## try
            # puts "AAAAAAAAAAAAA #{callback}"
    
            @form = result.call(callback, '<input type="submit" value="' + t("click_to_begin_3d_secure_verification") + '">') 
            # can't use redirect (easily) here since we want to pass @form
            render :action => 'enter_3dsecure' and return
          end
        end
      end

    rescue Spree::GatewayError => ge
      flash[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
      redirect_to edit_object_url and return
    end
  end
 
  update do
    flash nil
    
    success.wants.html do  
      # new: defer until later
    end 

    success.wants.js do   
      @order.reload
      render :json => { :order_total => number_to_currency(@order.total),
                        :charges => charge_hash,
                        :available_methods => rate_hash}.to_json,
             :layout => false
    end
  end
  
  update.before do
    if params[:checkout]
      # prevent double creation of addresses if user is jumping back to address stup without refreshing page
      params[:checkout][:bill_address_attributes][:id] = @checkout.bill_address.id if @checkout.bill_address
      params[:checkout][:ship_address_attributes][:id] = @checkout.ship_address.id if @checkout.ship_address
    end
    @checkout.ip_address ||= request.env['REMOTE_ADDR']
    @checkout.email = current_user.email if current_user && @checkout.email.blank?
    @order.update_attribute(:user, current_user) if current_user and @order.user.blank?
  end    
    
  private
  def object
    return @object if @object
    default_country = Country.find Spree::Config[:default_country_id]
    @object = parent_object.checkout                                                  
    @object.ship_address ||= Address.new(:country => default_country)
    @object.bill_address ||= Address.new(:country => default_country)   
    @object.creditcard   ||= Creditcard.new(:month => Date.today.month, :year => Date.today.year)
    @object         
  end
  
  def load_data     
    @countries = Country.find(:all).sort  
    @shipping_countries = parent_object.shipping_countries.sort
    default_country = Country.find Spree::Config[:default_country_id]
    @states = default_country.states.sort
  end
  
  def rate_hash       
    fake_shipment = Shipment.new :order => @order, :address => @order.ship_address
    @order.shipping_methods.collect do |ship_method| 
      { :id   => ship_method.id, 
        :name => ship_method.name, 
        :rate => number_to_currency(ship_method.calculate_shipping(fake_shipment)) }
    end
  end
  
  def charge_hash
    Hash[*@order.charges.collect { |c| [c.description, number_to_currency(c.amount)] }.flatten]    
  end  
end
