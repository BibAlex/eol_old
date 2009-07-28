# Put a few taxa (all within a new hierarchy) in the database with a range of accoutrements
#
#   TODO add a description here of what actually gets created!
#
#   This description block can be viewed (as well as other information 
#   about this scenario) by running:
#     $ rake scenarios:show NAME=bootstrap
#
# ---
# dependencies: [ :foundation ]
# arbitrary_variable: arbitrary value

require 'spec/eol_spec_helpers'
# This gives us the ability to recalculate some DB values:
include EOL::Data
# This gives us the ability to build taxon concepts:
include EOL::Spec::Helpers

# A singleton that creates some users:
def bootstrap_users
  @@bootstrap_users ||= []
  return @@bootstrap_users unless @@bootstrap_users.length == 0
  12.times { @@bootstrap_users << User.gen }
  return @@bootstrap_users
end

# A singleton that creates a 12-item TOC once and only once:
def bootstrap_toc
  @@bootstrap_toc ||= [TocItem.overview, TocItem.description]
  return @@bootstrap_toc unless @@bootstrap_toc.length == 1
  toc_len  = 1
  12.times do
    @@bootstrap_toc << TocItem.gen(:parent_id  => (rand(100) > 70) ? @@bootstrap_toc.last.id : 0, :view_order => (toc_len += 1))
  end
  return @@bootstrap_toc
end

#### Real work begins

Rails.cache.clear # We appear to be altering some of the cached classes here.  JRice 6/26/09

# Before we create our new taxa, we should make sure the RandomTaxa table is clear of bogus entries:
RandomTaxon.all.each do |rt|
  RandomTaxon.delete("id = #{rt.id}") if (TaxonConcept.find(rt.taxon_concept_id)).nil?
end

# TODO - I am neglecting to set up agent content partners, curators, contacts, provided data types, or agreements.  For now.

resource = Resource.gen(:title => 'Bootstrapper', :resource_status => ResourceStatus.published)
event    = HarvestEvent.gen(:resource => resource)
AgentsResource.gen(:agent => Agent.catalogue_of_life, :resource => resource,
                   :resource_agent_role => ResourceAgentRole.content_partner_upload_role)

gbif_agent = Agent.gen(:full_name => "Global Biodiversity Information Facility (GBIF)")
#gbif_agent = Agent.find_by_full_name('Global Biodiversity Information Facility (GBIF)');
AgentContact.gen(:agent => gbif_agent, :agent_contact_role => AgentContactRole.primary)
gbif_hierarchy = Hierarchy.gen(:agent => gbif_agent, :label => "GBIF Nub Taxonomy")

kingdom = build_taxon_concept(:rank => 'kingdom', :canonical_form => 'Animalia', :common_names => ['Animals'],
                              :event => event)
4.times do
  build_taxon_concept(:parent_hierarchy_entry_id => Hierarchy.default.hierarchy_entries.last.id,
                      :depth => Hierarchy.default.hierarchy_entries.length,
                      :event => event,
                      :common_names => [Factory.next(:common_name)])
end

fifth_entry_id = Hierarchy.default.hierarchy_entries.last.id
depth_now      = Hierarchy.default.hierarchy_entries.length

# Sixth Taxon should have more images, and have videos:
tc = build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [Factory.next(:common_name)],
                         :depth => depth_now, :images => :testing, :event => event)

# Seventh Taxon (sign of the apocolypse?) should be a child of fifth and be "empty", other than common names:
build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [Factory.next(:common_name)],
                    :depth => depth_now, :images => [], :toc => [], :flash => [], :youtube => [], :comments => [],
                    :bhl => [], :event => event)

# Eighth Taxon (now we're just getting greedy) should be the same as Seven, but with BHL:
build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [Factory.next(:common_name)],
                    :depth => depth_now, :images => [], :toc => [], :flash => [], :youtube => [], :comments => [],
                    :event => event)

# Ninth Taxon is *totally* naked:
build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [], :bhl => [], :event => event,
                    :depth => depth_now, :images => [], :toc => [], :flash => [], :youtube => [], :comments => [])

#20 has unvetted images and videos:         
build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [Factory.next(:common_name)],
                    :depth => depth_now, :images => [{}, {:vetted => Vetted.untrusted}, {:vetted => Vetted.unknown}], :flash => [{:vetted => Vetted.untrusted}], :youtube => [{:vetted => Vetted.untrusted}], :comments => [],
                    :bhl => [], :event => event)

# Now that we're done with CoL, we add another content partner who overlaps with them:
       # Give it a new name:
name   = Name.gen(:canonical_form => tc.canonical_form_object, :string => n = Factory.next(:scientific_name),
                  :italicized     => "<i>#{n}</i> #{Factory.next(:attribution)}")
agent2 = Agent.gen :username => 'test_cp'
cp     = ContentPartner.gen :vetted => true, :agent => agent2
cont   = AgentContact.gen :agent => agent2, :agent_contact_role => AgentContactRole.primary
r2     = Resource.gen(:title => 'Test ContentPartner import', :resource_status => ResourceStatus.processed)
ev2    = HarvestEvent.gen(:resource => r2)
ar     = AgentsResource.gen(:agent => agent2, :resource => r2, :resource_agent_role => ResourceAgentRole.content_partner_upload_role)
hier   = Hierarchy.gen :agent => agent2
he     = build_hierarchy_entry 0, tc, name, :hierarchy => hier
img    = build_data_object('Image', "This should only be seen by ContentPartner #{cp.description}",
                           :taxon => tc.images.first.taxa[0],
                           :hierarchy_entry => he,
                           :object_cache_url => Factory.next(:image),
                           :vetted => Vetted.unknown,
                           :visibility => Visibility.preview)

# Some node in the GBIF Hierarchy to test maps on
build_hierarchy_entry 0, tc, name, :hierarchy => gbif_hierarchy, :identifier => '13810203'

# Generate a default admin user and then set them up for the default roles:
admin = User.gen :username => 'admin', :password => 'admin', :given_name => 'Admin', :family_name => 'User'
admin.roles = Role.find(:all, :conditions => 'title LIKE "Administrator%"')
admin.save

#user for selenium tests
test_user2 = User.gen(:username => 'test_user2', :password => 'password', :given_name => 'test', :family_name => 'user2')
test_user2.save

#curator for selenium tests (NB: page #20)
curator = User.gen(:username => 'test_curator', :password => 'password', 'given_name' => 'test', :family_name => 'curator', :curator_hierarchy_entry_id => 5, :curator_approved => true)
curator.save

make_all_nested_sets
recreate_normalized_names_and_links

exemplar = build_taxon_concept(:event => event, :common_names => ['wumpus'], :id => 910093) # That ID is one of the (hard-coded) exemplars.

# Adds a ContentPage at the following URL: http://localhost:3000/content/page/curator_central

ContentPage.gen(:page_name => "curator_central", :title => "Curator central", :left_content => "")

# TODO - we need to build TopImages such that ancestors contain the images of their descendants










# creating collection / mapping data
image_collection_type = CollectionType.gen(:label => "Images")
specimen_image_collection_type = CollectionType.gen(:label => "Specimen", :parent_id => image_collection_type.id)
natural_image_collection_type = CollectionType.gen(:label => "Natural", :parent_id => image_collection_type.id)

species_pages_collection_type = CollectionType.gen(:label => "Species Pages")
molecular_species_pages_collection_type = CollectionType.gen(:label => "Molecular", :parent_id => species_pages_collection_type.id)
novice_pages_collection_type = CollectionType.gen(:label => "Novice", :parent_id => species_pages_collection_type.id)
expert_pages_collection_type = CollectionType.gen(:label => "Expert", :parent_id => species_pages_collection_type.id)

themes_collection_type = CollectionType.gen(:label => "Themes")
marine_theme_collection_type = CollectionType.gen(:label => "Marine", :parent_id => themes_collection_type.id)
bugs_theme_collection_type = CollectionType.gen(:label => "Bugs", :parent_id => themes_collection_type.id)

rebuild_collection_type_nested_set


name = tc.entry.name_object

specimen_image_collection = Collection.gen(:title => 'AntWeb', :description => 'Currently AntWeb contains information on the ant faunas of several areas in the Nearctic and Malagasy biogeographic regions, and global coverage of all ant genera.', :uri => 'http://www.antweb.org/specimen.do?name=FOREIGNKEY', :link => 'http://www.antweb.org/', :logo_url => 'antweb.png')
CollectionTypesCollection.gen(:collection => specimen_image_collection, :collection_type => specimen_image_collection_type)
CollectionTypesCollection.gen(:collection => specimen_image_collection, :collection_type => expert_pages_collection_type)
CollectionTypesCollection.gen(:collection => specimen_image_collection, :collection_type => bugs_theme_collection_type)
Mapping.gen(:collection => specimen_image_collection, :name => name, :foreign_key => 'casent0129891')
Mapping.gen(:collection => specimen_image_collection, :name => name, :foreign_key => 'casent0496198')
Mapping.gen(:collection => specimen_image_collection, :name => name, :foreign_key => 'casent0179524')


molecular_species_pages_collection = Collection.gen(:title => 'National Center for Biotechnology Information', :description => 'Established in 1988 as a national resource for molecular biology information, NCBI creates public databases, conducts research in computational biology, develops software tools for analyzing genome data, and disseminates biomedical information - all for the better understanding of molecular processes affecting human health and disease', :uri => 'http://www.ncbi.nlm.nih.gov/sites/entrez?Db=genomeprj&cmd=ShowDetailView&TermToSearch=FOREIGNKEY', :link => 'http://www.ncbi.nlm.nih.gov/', :logo_url => 'ncbi.png')
CollectionTypesCollection.gen(:collection => molecular_species_pages_collection, :collection_type => molecular_species_pages_collection_type)
CollectionTypesCollection.gen(:collection => molecular_species_pages_collection, :collection_type => marine_theme_collection_type)
Mapping.gen(:collection => molecular_species_pages_collection, :name => name, :foreign_key => '13646')
Mapping.gen(:collection => molecular_species_pages_collection, :name => name, :foreign_key => '9551')
