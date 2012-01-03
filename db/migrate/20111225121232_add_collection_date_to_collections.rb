class AddCollectionDateToCollections < ActiveRecord::Migration
  def self.up
    add_column :collections, :collection_date, :date
  end

  def self.down
    remove_column :collections, :collection_date
  end
end
