module Spree
  module PaymentGatewayForProtx3ds
    # intended to supplement the existing PG
    include Spree::PaymentGateway

    # transplanted from modified active merchant, should be unpicked later
    def PaymentGatewayForProtx3ds.requires_3dsecure?(response)
      response.params["Status"] == "3DAUTH"
    end


    def authorize(amount, options = {})
      gateway = payment_gateway       
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = gateway.authorize((amount * 100).to_i, self, gateway_options(options))

      if response.success?
        # create a creditcard_payment for the amount that was authorized

        checkout.order.new_payment(self, 0, amount, response.authorization, CreditcardTxn::TxnType::AUTHORIZE) 

      elsif PaymentGatewayForProtx3ds.requires_3dsecure?(response)
        # save a transaction -- but without a response code
        # store the MD code instead to allow finding of txn later (TODO: abstract)
        the_md = response.params["MD"]

        # reuse a previous incomplete transaction structure
        # ugly fudge here - TODO revisit when payment repres is simplified.
        prev_trans = checkout.order.payments.last.txns.last unless checkout.order.payments.empty? || checkout.order.payments.last.txns.empty?
        if prev_trans.nil? || ! prev_trans.response_code.blank?
          transaction = checkout.order.new_payment(self, 0, amount, nil, CreditcardTxn::TxnType::AUTHORIZE) 
        else 
          transaction = prev_trans
          prev_trans.creditcard_payment.amount = amount
          prev_trans.creditcard_payment.creditcard = self
          prev_trans.creditcard_payment.save
        end 
        transaction.md = the_md
        transaction.save
        gateway.form_for_3dsecure_verification(response.params)
      else
        gateway_error(response) 
      end
    end

    # doesn't require CC state - only depends on the parameters
    def complete_3dsecure(params)
      params["VendorTxCode"] = checkout.order.vtx_code
      response = payment_gateway.complete_3dsecure(params)
      gateway_error(response) unless response.success?          

      txn = CreditcardTxn.find_by_md(params["MD"])
      txn.response_code = response.authorization
      txn.save
    end

    # extended version, to allow passing extra options to AM    
    def gateway_options(options = {})
      addresses = {:billing_address  => generate_address_hash(address), 
                   :shipping_address => generate_address_hash(checkout.ship_address)}
      addresses.merge(minimal_gateway_options).merge options
    end    
    
  end
end
