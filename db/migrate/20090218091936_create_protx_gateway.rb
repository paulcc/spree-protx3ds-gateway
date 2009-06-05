class CreateProtxGateway < ActiveRecord::Migration
  def self.up
    return if true    # migration order problems

    protx = Gateway.create(
      :clazz => 'ActiveMerchant::Billing::Protx3dsGateway',
      :name => 'Protx3ds',
      :description => "Active Merchant's Protx 3ds Gateway (IE/UK)" 
    ) 

    GatewayOption.create(:name => 'login', :description => 'Your Protx Vendor Name (remember to set the server IP addresses in your VSP account)', :gateway_id => protx.id, :textarea => false)

    GatewayOption.create(:name => 'account', :description => 'Protx sub account name (optional)', :gateway_id => protx.id, :textarea => false)
  end

  def self.down
    protx = Gateway.find_by_name('Protx3ds')
    protx.destroy
  end
end
