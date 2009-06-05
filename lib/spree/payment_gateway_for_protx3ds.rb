module Spree
  module PaymentGatewayForProtx3ds
    # intended to supplement the existing PG

    # transplanted from modified active merchant, should be unpicked later
    def PaymentGateway.requires_3dsecure?(response)
      response.params["Status"] == "3DAUTH"
    end


    def authorize(amount, options = {})
      gateway = payment_gateway       
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = gateway.authorize((amount * 100).to_i, self, gateway_options(options))

      if response.success?
        # create a creditcard_payment for the amount that was authorized

        order.new_payment(self, 0, amount, response.authorization, CreditcardTxn::TxnType::AUTHORIZE) 

      elsif PaymentGateway.requires_3dsecure?(response)
        # save a transaction -- but without a response code
        # store the MD code instead to allow finding of txn later (TODO: abstract)
        transaction = order.new_payment(self, 0, amount, nil, CreditcardTxn::TxnType::AUTHORIZE) 
        transaction.md = response.params["MD"]
        transaction.save
        gateway.form_for_3dsecure_verification(response.params)
      else
        gateway_error(response) 
      end

    end

    # doesn't require CC state - only depends on the parameters
    def complete_3dsecure(params)
      params["VendorTxCode"] = order.number
      response = payment_gateway.complete_3dsecure(params)
      gateway_error(response) unless response.success?          

      txn = CreditcardTxn.find_by_md(params["MD"])
      txn.response_code = response.authorization
      txn.save
    end

 #     def gateway_error(response)
 #       text = response.params['message'] || 
 #              response.params['response_reason_text'] ||
 #              response.message
 #       msg = "#{I18n.t('gateway_error')} ... #{text}"
 #       logger.error(msg)
 #       raise Spree::GatewayError.new(msg)
 #     end
 
    # extended version, to allow passing extra options to AM    
    def gateway_options(options = {})
      addresses = {:billing_address  => generate_address_hash(address), 
                   :shipping_address => generate_address_hash(order.ship_address)}
      addresses.merge(minimal_gateway_options).merge options
    end    
    
  end
end
