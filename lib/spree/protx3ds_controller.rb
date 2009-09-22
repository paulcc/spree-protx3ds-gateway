module Spree
  module Protx3dsController
    ## 3ds specifics, injected into checkout controller
    ## 
  
    def callback_3dsecure
      @callback = complete_3dsecure_order_checkout_url(Order.find_by_number(params[:order_id]), 
                                                       :protocol => 'https')
      render :action => "callback_3dsecure", :layout => false
    end
  
    def complete_3dsecure
      # need don't-do-again checks? and check for being "in progress"? 
      # no need? order = Order.find_by_number(params[:id])
      order = Order.find_by_number params[:order_id]
      begin
        ActiveRecord::Base.transaction do
          # pass confirmation codes back to gateway, and fill in response code
          # NOTE: completion does NOT require valid CC details

          # need this construct for an interrim lookup... (normally should go via payments)
          response = Creditcard.find_by_checkout_id(order.checkout.id).complete_3dsecure(params)

          # expect gateway to throw a wobbly if it can't proceed?
          order.complete
        end
        respond_to do |format|
          format.html {
            if order.checkout_complete
              if current_user
                current_user.update_attribute(:bill_address, order.bill_address)
                current_user.update_attribute(:ship_address, order.ship_address)
              end
              flash[:notice] = t('order_processed_successfully')
              order_params = {:checkout_complete => true}
              order_params[:order_token] = order.token unless order.user
              session[:order_id] = nil
              redirect_to order_url(order, order_params) and next
            else
              # this means a failed filter which should have thrown an exception
              flash[:notice] = "Unexpected error condition -- please contact site support"
              redirect_to edit_object_url and next
            end
          }
        end
      rescue Spree::GatewayError => ge
        flash[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
        redirect_to edit_object_url and return
      rescue Exception => oe
        flash[:error] = t("unable_to_authorize_credit_card") + ": #{oe.message}"
        redirect_to edit_object_url and return
      end
    end
  end
end
