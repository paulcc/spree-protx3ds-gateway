# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class Protx3dsGatewayExtension < Spree::Extension
  version "1.0"
  description "Supports the Protx/Sagepay 3ds gateway"
  url "http://yourwebsite.com/protx3ds_gateway"

  # Please use protx3ds_gateway/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate

    # load two modified/updated files for active merchant
    require File.join(Protx3dsGatewayExtension.root, "lib", "active_merchant", "billing", "gateways", "protx.rb")
    require File.join(Protx3dsGatewayExtension.root, "lib", "active_merchant", "billing", "gateways", "protx3ds.rb")


    # NOTE: monkey patch the extended gateway interface into place
    Creditcard.class_eval do
      # add gateway methods to the creditcard so we can authorize, capture, etc.
      # this needs to be loaded after the standard gateway
      include Spree::PaymentGatewayForProtx3ds

      # request that a card payment to use 3ds
      attr_accessor :use_3ds
    end

    # and use the modified checkout code
    # NOTE: it's in its own module, to help work towards later use of multiple gateways
    OrdersController.class_eval do 
      include Spree::Protx3dsCheckout
      ssl_required :complete_3dsecure, :callback_3dsecure
      # TODO: work out why auth token is being rejected - faulty encoding??
      protect_from_forgery :except => :callback_3dsecure
    end

    # NOTE: monkey patch until spree master catches up
    Order.class_eval do 
      # register a new creditcard payment sequence, returning the actual transaction added
      def new_payment(card, taken_amount, auth_amount, auth_code, txn_type)
        payment = creditcard_payments.create(:amount => taken_amount, :creditcard => card)
        # create a transaction to reflect the authorization
        transaction = CreditcardTxn.new( :amount => auth_amount,
                                         :response_code => auth_code,
                                         :txn_type => txn_type )
        payment.creditcard_txns << transaction
        transaction
      end
    end
  end
end
