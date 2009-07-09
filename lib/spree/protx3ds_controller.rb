module Spree
  module Protx3dsController
    ## 3ds specifics, injected into checkout controller
    ## 
  
    def callback_3dsecure
      @callback = request.protocol + request.host_with_port + "/orders/#{params[:id]}/checkouts/complete_3dsecure"
      @callback = complete_3dsecure_order_checkout_url(Order.find_by_number params[:order_id])
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
            # copied verbatim from checkout.update code - can share??
            flash[:notice] = t('order_processed_successfully')
            order_params = {:checkout_complete => true}
            order_params[:order_token] = order.token unless order.user
            session[:order_id] = nil if order.checkout.completed_at
            redirect_to order_url(order, order_params) and next ## ?? if params[:final_answer]
          }
        end
      rescue Spree::GatewayError => ge
        flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
        render :action => "checkout" and return 
      end
    end
  end
end
