module Spree::UpdateMethod 
  def update 
    begin
      rc_update	# to load/save everything else

      # this bit replicates the save code from checkout model
      if @checkout.process_creditcard?

        @order.vtx_code = @order.number + "-0" if @order.vtx_code.nil?
        @order.update_attribute(:vtx_code, @order.vtx_code.succ)

        cc = Creditcard.new(@checkout.creditcard.merge(:address => @checkout.bill_address, :checkout => @checkout))
        # this call triggers 'prepare' but we also want to check for valid card type 
        cc.valid? || raise(Exception.new("card number or card type is invalid"))

        result = cc.authorize(@order.total, :order_id => @order.vtx_code)

        # this save should not fail unless there's a bug in authorize
        cc.save || raise(Exception.new("internal problem - please contact administrator"))

        if result.is_a?(Proc)
          raise "got here"
          @order.save                       # and save what we have

          callback = callback_3dsecure_order_checkout_url(@order, :protocol => 'https') + "?authenticity_token=#{form_authenticity_token}" 
  
          @form = result.call(callback, "<input type='submit' value='#{t 'click_to_begin_3d_secure_verification'}'/>")
          # can't use redirect (easily) here since we want to pass @form
          render :action => 'enter_3dsecure' and return
        end
      end

    rescue Spree::GatewayError => ge
      flash[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
      redirect_to edit_object_url and return
    rescue Exception => oe
      flash[:error] = t("unable_to_authorize_credit_card") + ": #{oe.message}"
      logger.unknown "#{flash[:error]}  #{oe.backtrace.join("\n")}"
      redirect_to edit_object_url and return
    end
  end
end
