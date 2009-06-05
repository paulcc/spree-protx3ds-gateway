= Protx3ds Gateway

* The 3ds code has been extended from http://github.com/andyjeffries/active_merchant/commit/d25199d218e06cb20d61268d39cdb050fe54bd85

* file lib/active_merchant/billing/gateways/protx.rb is the edge version of protx.rb, from the last relevant 
  commit at http://github.com/Shopify/active_merchant/commit/ebbd281f245f61290da1bc8d9e5e6881c11ef12b.
 
* the above version is NOT in version 1.4.2 (it was added afterwards) - so you either need to use the 
  edge version of active merchant, or arrange for (ie interpose) the local copy to take precedence some way




= Things to watch

WARNING: resubmitting an order after the 1st step of auth causes rejection - protx requires a unique VTX



