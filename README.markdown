= Protx3ds Gateway

See my fork of spree-demo to see this extension properly configured and in use. 
It's at http://github.com/paulcc/spree-demo/tree


* The 3ds code has been extended from http://github.com/andyjeffries/active_merchant/commit/d25199d218e06cb20d61268d39cdb050fe54bd85

* file lib/active_merchant/billing/gateways/protx.rb is the edge version of protx.rb, from the last relevant 
  commit at http://github.com/Shopify/active_merchant/commit/ebbd281f245f61290da1bc8d9e5e6881c11ef12b.
 
* the above version is NOT in version 1.4.2 (it was added afterwards) - so you either need to use the 
  edge version of active merchant, or arrange for (ie interpose) the local copy to take precedence some way


= Things to watch

WARNING: resubmitting an order after the 1st step of auth causes rejection because protx requires a unique VTX.I've got a crude hack to add a 4-digit time value to the end of an order number, but we should do better here.

NOTE: callback_3dsecure is exempt from protect_from_forgery - something is going wrong with the auth_token for this stage of the process (this should be investigated)


= Configuration

If you use my initializer code below, then you need to put your vendor name in the file +which_vendor+.
This is the name that identifies your protx main account (not the sub-account).

This mechanism is only done to hide the names of my test accounts, so you can to replace that File read with a string
in your own sites etc




= Using this extension

I used the following code in an initializer...

@
# put in test mode

Spree::Gateway::Config.set(:use_bogus => false)
ActiveMerchant::Billing::Base.gateway_mode = :test
# ActiveMerchant::Billing::Protx3dsGateway.simulate = true

# force this on, to avoid having to fix url protocols etc
Spree::Config.set(:allow_ssl_in_development_and_test => true)

# setup protx / sagepay
gw = Gateway.find_by_name("Protx3ds")


if gw.nil? 
  puts "WARNING: protx gateway configuration lost."
else
  puts " *** setting the unique gateway to Protx3ds *** "
  GatewayConfiguration.destroy_all
  gc = GatewayConfiguration.create :gateway => gw
  go = GatewayOption.find_by_gateway_id_and_name(gc.gateway.id, "login")
  gp = GatewayOptionValue.create :gateway_configuration => gc,
                                 :gateway_option => go,
                                 :value => File.read("which_vendor").chomp
end
@


# Issues / TODO

  1. Check handling of new Maestro type - AM doesn't handle it yet (and the regexps aren't up to date)

