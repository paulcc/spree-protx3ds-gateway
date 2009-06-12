class AddVtxCode < ActiveRecord::Migration
  def self.up
    add_column :orders, :vtx_code, :string
  end

  def self.down
    remove_column :orders, :vtx_code
  end
end
