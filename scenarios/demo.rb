# Creates a few named and numbered entries in the table with specific data expected to be encountered during a demo
# for potential funding sources.  Showcases feeds, communities, and collections.
#
# Note that this does NOT include prerequisite scenarios.  It is intended to run against a staging/integration style
# database and running foundation or the like would be... very, very bad.  (foundation truncates tables.)
#
# Please be very, very careful loading scenarios against large databases.

require 'spec/eol_spec_helpers'
require 'spec/scenario_helpers'
# This gives us the ability to recalculate some DB values:
include EOL::Data
# This gives us the ability to build taxon concepts:
include EOL::Spec::Helpers


def next_image
  @total_test_images = 8
  @image_number ||= 4
  @image_number = (@image_number + 1) % @total_test_images
  1000 + @image_number
end

summary = []
summary[0] =  {:text => '<p>Commonly known as the fly agaric or fly Amanita, Amanita muscaria is a mycorrhizal basidiomycete
    fungus that contains several toxic, psychoactive compounds. Amanita muscaria is the typical “toadstool” mushroom,
    bearing white gills and white warts on its variably colored cap and growing typically in clusters near conifers
  or hardwoods throughout the northern hemisphere</p><p>The name fly agaric comes from its use as a control for pesky flies. The old practice was to soaking pieces of
  the mushroom in a saucer of milk to attract flies. The flies would drink the tainted milk, become intoxicated, and
  fly into walls to their death.</p>',:lang => 'en'}
summary[1] =  {:text => '<p>والمعروف باسم غاريقون تطير أو تطير الأمانيت، الأمانيت muscaria هو basidiomycete الميكوريزا
     الفطريات السامة التي تحتوي على عدة والمركبات النفسانية. الأمانيت muscaria هو نموذجي "الفطر" عيش الغراب،
     مع الخياشيم البيضاء والبثور البيضاء على غطائها الملونة بنسب مختلفة ومتزايدة عادة في مجموعات قرب الصنوبريات
   أو الأخشاب في جميع أنحاء نصف الكرة الشمالي </ P> وتطير غاريقون اسم يأتي من استخدامه كعنصر تحكم عن الذباب المزعج. كانت الممارسة القديمة لقطع من تمرغ
   الفطر في الصحن من الحليب لاجتذاب الذباب. فإن الذباب شرب الحليب الملوث، وتصبح حالة سكر، و
   تطير في الجدران لموتهم. </ P>',:lang => 'ar'} 
summary[2] =  {:text => '<p> Communément appelé la volée ou amanite tue-mouche Amanita, Amanita muscaria est un basidiomycète mycorhiziens
     champignon qui contient plusieurs toxiques, de composés psychoactifs. Amanita muscaria est le typique "champignon" champignon,
     portant des branchies blanches et les verrues blanches sur son capuchon de couleur variable et croissante généralement en grappes à proximité de conifères
   ou de feuillus dans l\'hémisphère nord </ p> L\'amanite tue-mouche nom vient de son utilisation comme un contrôle des mouches des embêtants. L\'ancienne pratique était de trempage des pièces
   le champignon dans une soucoupe de lait pour attirer les mouches. Les mouches ne boire le lait contaminé, s\'enivrer, et
   voler dans les murs de leur mort. </ p>',:lang => 'fr'}

# We need to build the taxa, if they don't exist:
taxa = []

species = [
  {
    :id => 5559,
    :depth => 1,
    :sci => 'Fungi',
    :common => 'Mushrooms, sac fungi, lichens, yeast, molds, rusts, etc.',
    :rank => 'kingdom'},
  {
    :id => 1,
    :depth => 1,
    :sci => 'Animalia',
    :common => 'Animals',
    :rank => 'kingdom'},
  {
    :id => 3352,
    :depth => 1,
    :sci => 'Chromista',
    :rank => 'kingdom'},
  {
    :id => 281,
    :depth => 1,
    :sci => 'Plantae',
    :common => 'Plants',
    :rank => 'kingdom'},
  { :id => 2861424, :depth => 5, :parent => 5559, :sci => 'Amanitaceae', :rank => 'family' },
  { :id => 18878, :depth => 4, :parent => 2861424, :sci => 'Amanita', :rank => 'genus' },
  { :id => 7160, :depth => 5, :parent => 1, :sci => 'Nephropidae', :rank => 'family' },
  { :id => 17954507, :depth => 5, :parent => 7160, :sci => 'Dinochelus', :rank => 'genus' },
  { :id => 3594, :depth => 4, :parent => 3352, :sci => 'Raphidophyceae', :rank => 'family' },
  { :id => 89513, :depth => 5, :parent => 3594, :sci => 'Haramonas', :rank => 'genus' },
  { :id => 7676, :depth => 4, :parent => 1, :sci => 'Canidae', :common => 'Coyotes, dogs, foxes, jackals, and wolves', :rank => 'family' },
  { :id => 14460, :depth => 5, :parent => 7676, :sci => 'Canis', :common => 'Wolf', :rank => 'species', :rank => 'genus' },
  { :id => 6747, :depth => 4, :parent => 281, :sci => 'Pinaceae ', :common => 'Pine trees', :rank => 'family' },
  { :id => 14031, :depth => 5, :parent => 6747, :sci => 'Pinus ', :common => 'Pine', :rank => 'genus' },
  { :id => 699, :depth => 4, :parent => 1, :sci => 'Formicidae', :rank => 'family' },
  { :id => 49148, :depth => 5, :parent => 699, :sci => 'Anochetus', :rank => 'genus' },
  { :id => 2866150, :parent => 18878,
    :sci => 'Amanita muscaria',
    :attribution => '(L. ex Fr.) Hook.',
    :common => 'Fly Agaric',
    :imgs => [201008242207638, 201101141341094, 201101141330049, 201101141305714],
    :summary => summary,               
    :rank => 'species'}
  
]



animalia_entry = TaxonConcept.find(1).entry.id
overv = TocItem.find_by_translated(:label, 'Brief Summary')

species.each_with_index do |info, which|
  puts which
  id = info[:id]
  tc = nil
  begin
    tc = TaxonConcept.find(id)
    puts "** FOUND #{info[:sci]} (#{id})..."
  rescue => e
    puts e.message
    parent = info.has_key?(:parent) ?
      TaxonConcept.find(info[:parent]).entry.id :
      animalia_entry
        
    tocs = []
    if info.has_key? :summary
      info[:summary].each do |sum|
        tocs << { :toc_item => overv, 
                  :description => sum[:text]? sum[:text] : 'Just a placeholder text for the description of this species', 
                  :language => sum[:lang]? Language.from_iso(sum[:lang]) : Language.english }
      end
      
    else
      tocs << { :toc_item => overv, 
                  :description => 'Just a placeholder text for the description of this species', 
                  :language => Language.english }
    end
      
           
    imgs = []
    if info.has_key? :imgs
      info[:imgs].each do |i|
        imgs << {:object_cache_url => i}
      end
    end
    commons = [info[:common]].compact
    puts "** Building #{info[:sci]} (#{id})..."
    tc = build_taxon_concept(
      :id => id,
      :parent_hierarchy_entry_id => parent,
      :canonical_form => info[:sci],
      :attribution => info[:attribution] || '',
      :common_names => commons,
      :depth => info[:depth] || nil,
      :rank => info[:rank] || nil,
      :flash => [],
      :youtube => [],
      :toc => tocs, 
      :images => imgs
    )
  
  end
  taxa << tc if info.has_key?(:summary)
  if info[:depth] == 1
    entry = tc.entry
    entry.parent_id = 0 # I hope this makes it NOT under animalia!
    entry.save!
  end
end

# Special: we want to ensure that TC 1 is really called "Animalia".  A little harsh, but:
animalia = TaxonConcept.find(1)
obj = animalia.canonical_form_object
obj.string = "Animalia"
obj.save!
obj = Name.find(animalia.entry.name_id)
obj.string = "Animalia"
obj.clean_name = 'animalia'
obj.italicized = '<i>Animalia</i>'
obj.save!

community_owner = User.first
community_owner.logo_cache_url = 1003
community_owner.save

community_name = 'Columbia Intro Biology'
community = Community.find_by_name(community_name)
community ||= Community.gen(:name => community_name, :description => 'This is a community intended to showcase the newest features of Version 2 for the EOL website.', :logo_cache_url => 2000)
community.initialize_as_created_by(community_owner)
com_col = community.focus
com_col.logo_cache_url = 2001
com_col.save!

collection_owner = User.find(community_owner.id + 1)
collection_owner.logo_cache_url = 1005
collection_owner.save

collection_name  = 'New Species from the Census of Marine Life'
endorsed_collection = Collection.find_by_name(collection_name)
endorsed_collection ||= Collection.gen(:user => collection_owner, :name => collection_name, :logo_cache_url => 3000)

# Empty the two collections:
community.focus.collection_items.each do |ci|
  ci.destroy
end
endorsed_collection.collection_items.each do |ci|
  ci.destroy
end

loud_user = User.find(community_owner.id + 2)
loud_user.logo_cache_url = 1001
loud_user.save
happy_user = User.find(community_owner.id + 3)
happy_user.logo_cache_url = 1002
happy_user.save
concerned = User.find(community_owner.id + 4)
concerned.logo_cache_url = 1003
concerned.save

# Now build them up again:
taxa.each do |tc|
  community.focus.add tc
  endorsed_collection.add tc
  Comment.gen(:parent => tc, :body => "Could we add some images of this in its natural habitat?", :user => loud_user)
  Comment.gen(:parent => tc, :body => "Beautiful!", :user => happy_user)
  Comment.gen(:parent => tc, :body => "There are serious concerns about this species becoming endangered", :user =>
              concerned)
end

Comment.gen(:parent => endorsed_collection, :body => "Are there enough curators for this?", :user => loud_user)
Comment.gen(:parent => endorsed_collection, :body => "Excellent list!", :user => happy_user)
Comment.gen(:parent => endorsed_collection, :body => "Should't this have a few more ducks?", :user => concerned)

users = User.find(:all, :conditions => 'logo_cache_url IS NULL')
puts "Updating #{users.length} users..."
users.each_with_index do |user, i|
  puts "  #{i}" if (i % 10 == 0)
  user.logo_cache_url = next_image
  user.save
end

puts "Re-indexing.  Hang on, almost there."
make_all_nested_sets
rebuild_collection_type_nested_set
flatten_hierarchies

TaxonConcept.all.each do |tc|
  tc.save # This will save the record, thus indexing the concept with all its names
end

puts "Adding data_object translations relationships"
DataObjectTranslation.create(:data_object => DataObject.find_by_description(summary[1][:text]),:language => DataObject.find_by_description(summary[1][:text]).language, :original_data_object_id => DataObject.find_by_description(summary[0][:text]))
DataObjectTranslation.create(:data_object => DataObject.find_by_description(summary[2][:text]),:language => DataObject.find_by_description(summary[2][:text]).language, :original_data_object_id => DataObject.find_by_description(summary[0][:text]))
