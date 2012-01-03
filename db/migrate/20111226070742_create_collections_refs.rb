class CreateCollectionsRefs < ActiveRecord::Migration
  def self.up
    create_table :collections_refs, :id => false do |t|
      t.integer :collection_id, :null => false
      t.integer :ref_id, :null => false
    end
  end

  def self.down
    drop_table :collections_refs
  end
end
