require File.dirname(__FILE__) + '/../spec_helper'

def it_should_collect_item(collectable_item_path, collectable_item)
  visit collectable_item_path
  click_link 'Add to a collection'
  if current_url.match /#{login_url}/
    page.fill_in 'session_username_or_email', :with => @anon_user.username
    page.fill_in 'session_password', :with => 'password'
    click_button 'Sign in'
    continue_collect(@anon_user, collectable_item_path)
    visit logout_url
  else
    continue_collect(@user, collectable_item_path)
  end
end

def continue_collect(user, url)
  current_url.should match /#{choose_collect_target_collections_path}/
  check 'collection_id_'
  click_button 'Collect item'
  # TODO
  # current_url.should match /#{url}/
  # body.should include('added to collection')
  # user.watch_collection.items.map {|li| li.object }.include?(collectable_item).should be_true
end

describe "Collections and collecting:" do

  before(:all) do
    # so this part of the before :all runs only once
    unless User.find_by_username('collections_scenario')
      truncate_all_tables
      load_scenario_with_caching(:collections)
    end
    Capybara.reset_sessions!
    @test_data = EOL::TestInfo.load('collections')
    @collectable_collection = Collection.gen
    @collection = @test_data[:collection]
    @collection_owner = @test_data[:user]
    @user = nil
    @under_privileged_user = User.gen
    @anon_user = User.gen(:password => 'password')
    @taxon = @test_data[:taxon_concept_1]
    EOL::Solr::CollectionItemsCoreRebuilder.begin_rebuild
    EOL::Solr::DataObjectsCoreRebuilder.begin_rebuild
  end

  after(:all) do
  end

  shared_examples_for 'collections all users' do
    it 'should be able to view a collection and its items' do
      visit collection_path(@collection)
      body.should have_tag('h1', /#{@collection.name}/)
      body.should have_tag('ul.object_list li', /#{@collection.collection_items.first.object.best_title}/)
    end

    it "should be able to sort a collection's items" do
      visit collection_path(@collection)
      body.should have_tag('#sort_by')
    end

    it "should be able to change the view of a collection" do
      visit collection_path(@collection)
      body.should have_tag('#view_as')
    end

  end

  shared_examples_for 'collecting all users' do
    describe "should be able to collect" do
      it 'taxa' do
        it_should_collect_item(taxon_overview_path(@taxon), @taxon)
      end
      it 'data objects' do
        it_should_collect_item(data_object_path(@taxon.images_from_solr.first), @taxon.images_from_solr.first)
      end
      it 'communities' do
        new_community = Community.gen
        it_should_collect_item(community_path(new_community), new_community)
      end
      it 'collections, unless its their watch collection' do
        it_should_collect_item(collection_path(@collectable_collection), @collectable_collection)
        unless @user.nil?
          visit collection_path(@user.watch_collection)
          body.should_not have_tag('a.collect')
        end
      end
      it 'users' do
        new_user = User.gen
        it_should_collect_item(user_path(new_user), new_user)
      end
    end
  end

  # Make sure you are logged in prior to calling this shared example group
  shared_examples_for 'collections and collecting logged in user' do
    it_should_behave_like 'collections all users'
    it_should_behave_like 'collecting all users'

    it 'should be able to select all collection items on the page' do
      visit collection_path(@collection)
      body.should_not have_tag("input[id=?][checked]", "collection_item_#{@collection.collection_items.first.id}")
      visit collection_path(@collection, :commit_select_all => true) # FAKE the button click, since it's JS otherwise
      body.should have_tag("input[id=?][checked]", "collection_item_#{@collection.collection_items.first.id}")
    end

    it 'should be able to copy collection items to one of their existing collections' do
      visit collection_path(@collection, :commit_select_all => true) # Select all button is JS, fake it.
      click_button 'Copy selected'
      body.should have_tag('#collections') do
        with_tag('input[value=?]', @user.watch_collection.name)
      end
    end

    it 'should be able to copy collection items to a new collection' do
      visit collection_path(@collection, :commit_select_all => true) # Select all button is JS, fake it.
      click_button 'Copy selected'
      body.should have_tag('#collections') do
        with_tag('form.new_collection')
      end
    end
  end

  describe 'anonymous users' do
    before(:all) { visit logout_url }
    subject { body }
    it_should_behave_like 'collections all users'
    # it_should_behave_like 'collecting all users'
    it 'should not be able to select collection items' do
      visit collection_path(@collection)
      should_not have_tag("input#collection_item_#{@collection.collection_items.first.id}")
      should_not have_tag('input[name=?]', 'commit_select_all')
    end
    it 'should not be able to copy collection items' do
      visit collection_path(@collection)
      should_not have_tag("input#collection_item_#{@collection.collection_items.first.id}")
      should_not have_tag('input[name=?]', 'commit_copy_collection_items')
    end
    it 'should not be able to move collection items' do
      visit collection_path(@collection)
      should_not have_tag("input#collection_item_#{@collection.collection_items.first.id}")
      should_not have_tag('input[name=?]', 'commit_move_collection_items')
    end
    it 'should not be able to remove collection items' do
      visit collection_path(@collection)
      should_not have_tag("input#collection_item_#{@collection.collection_items.first.id}")
      should_not have_tag('input[name=?]', 'commit_remove_collection_items')
    end
  end

  describe 'user without privileges' do
    before(:all) {
      @user = @under_privileged_user
      login_as @user
    }
    after(:all) { @user = nil }
    it_should_behave_like 'collections all users'
    it_should_behave_like 'collecting all users'
    it 'should not be able to move collection items' do
      visit collection_path(@collection)
      should_not have_tag("input#collection_item_#{@collection.collection_items.first.id}")
      should_not have_tag('input[name=?]', 'commit_move_collection_items')
    end
    it 'should not be able to remove collection items' do
      visit collection_path(@collection)
      should_not have_tag("input#collection_item_#{@collection.collection_items.first.id}")
      should_not have_tag('input[name=?]', 'commit_remove_collection_items')
    end
  end

  describe 'user with privileges' do
    before(:all) {
      @user = @collection_owner
      login_as @user
    }
    after(:all) { @user = nil }
    it_should_behave_like 'collections all users'
    it_should_behave_like 'collecting all users'
    it 'should be able to move collection items'
    it 'should be able to remove collection items'
    it 'should be able to edit ordinary collection' do
      visit edit_collection_path(@collection)
      page.fill_in 'collection_name', :with => 'Edited collection name'
      click_button 'Update collection details'
      body.should have_tag('h1', 'Edited collection name')
    end
    it 'should be able to edit ordinary collection item attributes (with JS off, need Cucumber tests for JS on)'
    it 'should be able to delete ordinary collections'
    it 'should not be able to delete special collections'
    it 'should not be able to edit watch collection name' do
      visit edit_collection_path(@collection)
      body.should have_tag('#collections_edit') do
        with_tag('#collection_name', :val => "#{@collection.name}")
        without_tag('label', :text => "#{@user.watch_collection.name}")
      end
      visit edit_collection_path(@user.watch_collection)
      body.should have_tag('#collections_edit') do
        without_tag('#collection_name', :val => "#{@collection.name}")
        with_tag('label', :text => "#{@user.watch_collection.name}")
      end
    end
  end

  it "should always link collected objects to their latest published versions" do
    @original_index_records_on_save_value = $INDEX_RECORDS_IN_SOLR_ON_SAVE
    $INDEX_RECORDS_IN_SOLR_ON_SAVE = true
    login_as @anon_user
    visit data_object_path(@taxon.images_from_solr.first)
    click_link 'Add to a collection'
    current_url.should match /#{choose_collect_target_collections_path}/
    check 'collection_id_'
    click_button 'Collect item'
    collectable_data_object = @taxon.images_from_solr.first
    collectable_data_object.object_title = "Current data object"
    collectable_data_object.save

    # first time visiting - collected image should show up
    visit collection_path(@anon_user.watch_collection)
    body.should have_tag('ul.object_list li', /#{collectable_data_object.object_title}/)

    # the image will unpublished, but there are no newer versions, so it will still show up
    collectable_data_object.published = 0
    collectable_data_object.save
    visit collection_path(@anon_user.watch_collection)
    body.should have_tag('ul.object_list li', /#{collectable_data_object.object_title}/)

    # the image is still unpublished, but there's a newer version. We should see the new version in the collection
    newer_version_collected_data_object = DataObject.gen(:guid => @taxon.images_from_solr.first.guid,
      :object_title => "Latest published version", :published => true, :created_at => Time.now )
    visit collection_path(@anon_user.watch_collection)
    body.should have_tag('ul.object_list li', /#{newer_version_collected_data_object.object_title}/)
    body.should_not have_tag('ul.object_list li', /#{collectable_data_object.object_title}/)

    # the original image is published again, but this time we still see the newest version as we
    # always show the latest version of an object. This is a rare case where there are two published versions
    # of the same object, which technically shouldn't happen in production
    collectable_data_object.published = 1
    collectable_data_object.save
    visit collection_path(@anon_user.watch_collection)
    body.should have_tag('ul.object_list li', /#{newer_version_collected_data_object.object_title}/)
    body.should_not have_tag('ul.object_list li', /#{collectable_data_object.object_title}/)

    # finally, with each version published, we should not be able to add the latest version into our collection
    # as the collection already contains a version of this objects
    visit data_object_path(newer_version_collected_data_object)
    click_link 'Add to a collection'
    current_url.should match /#{choose_collect_target_collections_path}/
    body.should have_tag('li', /in collection/)

    # and deleting the first version from the collection will allow the new one to be added
    @anon_user.watch_collection.collection_items[0].destroy
    visit data_object_path(newer_version_collected_data_object)
    click_link 'Add to a collection'
    current_url.should match /#{choose_collect_target_collections_path}/
    body.should_not have_tag('li', /in collection/)


    newer_version_collected_data_object.destroy
    $INDEX_RECORDS_IN_SOLR_ON_SAVE = @original_index_records_on_save_value
  end

  it "collections should respect the max_items_per_page value of their ViewStyles and have appropriate rel link tags" do
    @original_index_records_on_save_value = $INDEX_RECORDS_IN_SOLR_ON_SAVE
    $INDEX_RECORDS_IN_SOLR_ON_SAVE = true

    collection_owner = User.gen(:password => 'somenewpassword')
    collection = collection_owner.watch_collection
    collection.view_style = ViewStyle.first
    collection.save

    # adding 7 items in the collection
    collection.add DataObject.gen
    collection.add DataObject.gen
    collection.add DataObject.gen
    collection.add DataObject.gen
    collection.add DataObject.gen
    collection.add DataObject.gen
    collection.add DataObject.gen

    # setting the collection's view style to one that allows 2 items per page
    TranslatedViewStyle.reset_cached_instances
    ViewStyle.reset_cached_instances
    v = ViewStyle.first
    v.max_items_per_page = 2
    v.save
    visit collection_path(collection)
    # there should be exactly 4 pages when we have a max_items_per_page of 2
    body.should match(/href="\/collections\/#{collection.id}\?page=4/)
    body.should_not match(/href="\/collections\/#{collection.id}\?page=5/)

    # on page 1 rel canonical should not include page number;  rel prev should not exist; rel next is page 2; title should not include page
    body.should have_tag('link[rel=canonical][href=?]', collection_url(collection))
    body.should_not have_tag('link[rel=prev]')
    body.should have_tag('link[rel=next][href=?]', /http:\/\/.*?\/collections\/#{collection.id}.*?page=2/)
    body.should_not have_tag('title', /page 1/i)
    # on page 2 rel canonical should include page 2; rel prev should be page 1; rel next should be page 3; title should include page
    visit collection_path(collection, :page => 2)
    body.should have_tag('link[rel=canonical][href=?]', collection_url(collection_owner.watch_collection, :page => 2))
    body.should have_tag('link[rel=prev][href=?]', /http:\/\/.*?\/collections\/#{collection.id}.*?page=1/)
    body.should have_tag('link[rel=next][href=?]', /http:\/\/.*?\/collections\/#{collection.id}.*?page=3/)
    body.should have_tag('title', / - page 2/i)
    # on last page there should be no rel next
    visit collection_path(collection, :page => 4)
    body.should have_tag('link[rel=canonical][href=?]', collection_url(collection_owner.watch_collection, :page => 4))
    body.should have_tag('link[rel=prev][href=?]', /http:\/\/.*?\/collections\/#{collection.id}.*?page=3/)
    body.should_not have_tag('link[rel=next]')
    body.should have_tag('title', / - page 4/i)

    TranslatedViewStyle.reset_cached_instances
    ViewStyle.reset_cached_instances
    v = ViewStyle.first
    v.max_items_per_page = 4
    v.save
    visit collection_path(collection_owner.watch_collection)
    # there should be exactly 2 pages when we have a max_items_per_page of 4
    body.should match(/href="\/collections\/#{collection.id}\?page=2/)
    body.should_not match(/href="\/collections\/#{collection.id}\?page=3/)

    $INDEX_RECORDS_IN_SOLR_ON_SAVE = @original_index_records_on_save_value
  end


  it 'collection newsfeed should have rel canonical link tag' do
    false
  end
  it 'collection newsfeed should have prev and next link tags if relevant' do
    false
  end
  it 'collection newsfeed should append page number to head title if relevant' do
    false
  end
  it 'collection editors should have rel canonical link tag' do
    false
  end
  it 'collection editors should not have prev and next link tags' do
    false
  end

end



describe "Preview Collections" do
  before(:all) do
    module Paperclip
      class Attachment
        def save
          # don't do anything. Paperclip was throwing an error
          true
        end
      end
    end

    unless User.find_by_username('collections_scenario')
      truncate_all_tables
      load_scenario_with_caching(:collections)
    end
    Capybara.reset_sessions!
    @test_data = EOL::TestInfo.load('collections')
    @collectable_collection = Collection.gen
    @collection = @test_data[:collection]
    @collection_owner = @test_data[:user]
    @user = nil
    @under_privileged_user = User.gen
    @anon_user = User.gen(:password => 'password')
    @taxon = @test_data[:taxon_concept_1]
    @collection.add(@taxon)
    EOL::Solr::CollectionItemsCoreRebuilder.begin_rebuild
  end

  it 'should show collections on the taxon page' do
    visit taxon_path(@taxon)
    body.should have_tag('#collections_summary') do
      with_tag('h3', :text => "Present in 1 collection")
    end
  end

  it 'should not show preview collections on the taxon page' do
    @collection.update_attribute(:published, false)
    visit taxon_path(@taxon)
    body.should have_tag('#collections_summary') do
      with_tag('h3', :text => "Present in 0 collections")
    end
    @collection.update_attribute(:published, true)
  end

  it 'should not show preview collections on the user profile page to normal users' do
    visit user_collections_path(@collection.users.first)
    body.should have_tag('li.active') do
      with_tag('a', :text => "3 collections")
    end
    body.should have_tag('h3', :text => "2 collections")
    @collection.update_attribute(:published, false)
    visit user_collections_path(@collection.users.first)
    body.should have_tag('li.active') do
      with_tag('a', :text => "2 collections")
    end
    body.should have_tag('div.heading') do
      with_tag('h3', :text => "1 collection")
    end
    @collection.update_attribute(:published, true)
  end

  it 'should show resource preview collections on the user profile page to the owner' do
    @collection.update_attribute(:published, false)
    @collection.update_attribute(:view_style_id, nil)
    @resource = Resource.gen
    @resource.preview_collection = @collection
    @resource.save
    login_as @collection.users.first
    visit user_collections_path(@collection.users.first)
    body.should have_tag('li.active') do
      with_tag('a', :text => "3 collections")
    end
    body.should have_tag('div.heading') do
      with_tag('h3', :text => "2 collections")
    end
    visit('/logout')
    @collection.update_attribute(:published, true)
  end

  it 'should allow EOL administrators and owners to view unpublished collections' do
    @collection.update_attribute(:published, false)
    @collection.update_attribute(:view_style_id, ViewStyle.annotated.id)
    if @collection.resource_preview.blank?
      @resource = Resource.gen
      @resource.preview_collection = @collection
      @resource.save
    end
    @collection.reload
    visit logout_path
    visit collection_path(@collection)
    current_path.should == login_path
    body.should include('You must be logged in to perform this action')
    user = User.gen(:admin => false)
    login_as user
    referrer = current_path
    visit collection_path(@collection)
    current_path.should == referrer
    body.should include('You are not authorized')
    visit logout_path

    admin = User.gen(:admin => true)
    login_as admin
    visit collection_path(@collection)
    body.should have_tag('h1', /#{@collection.name}/)
    body.should have_tag('ul.object_list li', /#{@collection.collection_items.first.object.best_title}/)
    visit logout_path

    login_as @collection.users.first
    visit collection_path(@collection)
    body.should have_tag('h1', /#{@collection.name}/)
    body.should have_tag('ul.object_list li', /#{@collection.collection_items.first.object.best_title}/)
    @collection.update_attribute(:published, true)
  end
end

#TODO: test connection with Solr: filter, sort, total results, paging, etc
