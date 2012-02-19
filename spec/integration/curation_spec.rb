require File.dirname(__FILE__) + '/../spec_helper'

def create_curator_for_taxon_concept(tc)
  curator = build_curator(tc)
  return curator
end

describe 'Curation' do

  before(:all) do
    truncate_all_tables
    load_foundation_cache
    Capybara.reset_sessions!
    commit_transactions # Curators are not recognized if transactions are being used, thanks to a lovely
                        # cross-database join.  You can't rollback, because of the EolScenario stuff.  [sigh]
    @common_names_toc_id = TocItem.common_names.id
    @parent_hierarchy_entry = HierarchyEntry.gen(:hierarchy_id => Hierarchy.default.id)
    @taxon_concept   = build_taxon_concept(:parent_hierarchy_entry_id => @parent_hierarchy_entry.id)
    @common_name     = 'boring name'
    @unreviewed_name = Faker::Eol.common_name.firstcap
    @untrusted_name  = Faker::Eol.common_name.firstcap
    @agents_cname    = Faker::Eol.common_name.firstcap
    agent = Agent.find(@taxon_concept.acting_curators.first.agent_id)
    @cn_curator = create_curator_for_taxon_concept(@taxon_concept)
    @common_syn = @taxon_concept.add_common_name_synonym(@common_name, :agent => agent, :language => Language.english,
                                           :vetted => Vetted.unknown, :preferred => false)
    @unreviewed_syn = @taxon_concept.add_common_name_synonym(@unreviewed_name, :agent => agent, :language => Language.english,
                                           :vetted => Vetted.unknown, :preferred => false)
    @untrusted_syn = @taxon_concept.add_common_name_synonym(@untrusted_name, :agent => agent, :language => Language.english,
                                           :vetted => Vetted.untrusted, :preferred => false)
    @agents_syn = @taxon_concept.add_common_name_synonym(@agents_cname, :agent => @cn_curator, :language => Language.english,
                                           :vetted => Vetted.trusted, :preferred => false)
    @first_curator = create_curator_for_taxon_concept(@taxon_concept)
    @default_num_curators = @taxon_concept.acting_curators.length
    make_all_nested_sets
    flatten_hierarchies

    visit("/pages/#{@taxon_concept.id}")
    @default_page  = source
    visit("/pages/#{@taxon_concept.id}/names/common_names")
    @non_curator_cname_page = source
    @new_name   = 'habrish lammer'
    @taxon_concept.add_common_name_synonym @new_name, :agent => Agent.find(@cn_curator.agent_id), :preferred => false, :language => Language.english
    login_as(@cn_curator)
    visit("/pages/#{@taxon_concept.id}/names/common_names")
    @cname_page = source
    visit('/logout')
  end

  after(:all) do
    truncate_all_tables
  end

  after(:each) do
    visit('/logout')
  end

  # TODO: commented out this entire block as none of the specs were enabled and it was eating up 25 seconds of spec time
  # context "on taxon overview" do
  #
  #   it 'should show a list of acting curators with a photo, curator name and expertise'
  #
  #   it 'should change the curator count if another curator curates an image'
  #     #num_curators = @taxon_concept.acting_curators.length
  #     #curator = create_curator_for_taxon_concept(@taxon_concept)
  #     #@taxon_concept.reload
  #     #@taxon_concept.acting_curators.length.should == num_curators + 1
  #     #visit("/pages/#{@taxon_concept.id}")
  #     #body.should have_tag('h2', :text => /#{num_curators + 1} curators/i)
  #
  #   it 'should change the number of curators if another curator curates a text object'
  #     #@taxon_concept.reload
  #     #num_curators = @taxon_concept.acting_curators.length
  #     #curator = create_curator_for_taxon_concept(@taxon_concept)
  #     #@taxon_concept.reload
  #     #@taxon_concept.acting_curators.length.should == num_curators + 1
  #     #visit("/pages/#{@taxon_concept.id}")
  #     #body.should have_tag('h2', :text => /#{num_curators + 1} curators/i)
  #
  #   it 'should have a link from name of curator to account page'
  #     #@default_page.should have_tag('div#curators_container') do
  #       #with_tag('a[href*=?]', /\/account\/show\/#{@taxon_concept.acting_curators.first.id}/)
  #     #end
  #
  #   it 'should not show curation button when not logged in (obsolete?)'
  #
  #   it 'should show curation (contribute?) button on taxon overview when logged in as curator'
  #
  #   it 'should not have a curation panel when not logged in as a curator (obsolete?)'
  #
  #   it 'should show the curator list link (obsolete?)'
  #
  #   it 'should show the curator list link when there has been no activity (obsolete?)'
  #
  #   it 'should say the page has citation (obsolete?)'
  #
  #   it 'should have a link from N curators to the citation (obsolete?)'
  #
  #   it 'should still have a curator name in citation after changing clade (obsolete?)'
  #     #@default_page.should have_tag('div#page-citation', /#{@first_curator.family_name}/)
  #     #uu = User.find(@first_curator.id)
  #     #uu.curator_hierarchy_entry_id = uu.curator_hierarchy_entry_id + 1
  #     #uu.save!
  #     #@first_curator = uu
  #     #visit("/pages/#{@taxon_concept.id}")
  #     #body.should have_tag('div#page-citation', /#{@first_curator.family_name}/)
  #
  #   it 'should display a "view/edit" link next to the common name in the header (obsolete?)'
  # end

  it 'should show a curator the ability to add a new common name' do
    login_as(@first_curator)
    visit("/pages/#{@taxon_concept.id}/names/common_names")
    body.should have_tag("form#new_name")
    body.should have_tag("form.update_common_names")
    visit('/logout')
  end

  it 'should show common name sources for curators' do
    @cname_page.should have_tag(".main_container .update_common_names") do
      # Curator Full Name, because we added the common name with agents_synonyms:
      with_tag("td", :text => /#{@taxon_concept.acting_curators.first.full_name}/)
    end
    visit('/logout')
  end

  # Note that this is essentially the same test as in taxa_page_spec... but we're a curator, now... and it uses a separate
  # view, so it needs to be tested.
  it 'should show all common names trust levels' do
    first_trusted_name =
      @taxon_concept.common_names.select {|n| n.vetted_id == Vetted.trusted.id}.map {|n| n.name.string}.sort[0]
    @cname_page.should have_tag(".main_container .update_common_names") do
      with_tag('td:nth-child(2)', :text => first_trusted_name)
      with_tag('td:nth-child(2)', :text => @unreviewed_name)
      with_tag('td:nth-child(2)', :text => @untrusted_name)
    end
  end

  it 'should show vetting drop-down for common names either NOT added by this curator or added by a CP' do
    @cname_page.should have_tag(".main_container .update_common_names") do
      with_tag("td:nth-child(4) option", :text => 'Trusted')
      with_tag("td:nth-child(4) option", :text => 'Unreviewed')
      with_tag("td:nth-child(4) option", :text => 'Untrusted')
    end
  end

  it 'should show delete link for common names added by this curator' do
    @cname_page.should have_tag(".main_container .update_common_names") do
      with_tag("a[href^=/#{I18n.locale.to_s}/pages/#{@taxon_concept.id}/names/delete?]", :text => /del/i)
    end
  end

  it 'should not show editing common name environment if curator is not logged in' do
    visit("/logout")
    visit("/pages/#{@taxon_concept.id}?category_id=#{TocItem.common_names.id}")
    body.should_not have_tag("form#add_common_name")
    body.should_not have_tag("form.update_common_names")
  end

end
