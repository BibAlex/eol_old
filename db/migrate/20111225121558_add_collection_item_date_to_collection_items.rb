class AddCollectionItemDateToCollectionItems < ActiveRecord::Migration
  def self.up
    add_column :collection_items, :collection_item_date, :date
  end

  def self.down
    remove_column :collection_items, :collection_item_date
  end
end
