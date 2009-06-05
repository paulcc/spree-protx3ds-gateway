class AddMdField < ActiveRecord::Migration
  def self.up
    add_column :creditcard_txns, :md, :string
  end

  def self.down
    remove_column :creditcard_txns, :md
  end
end
