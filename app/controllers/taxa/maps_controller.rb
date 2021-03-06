class Taxa::MapsController < TaxaController
  before_filter :instantiate_taxon_concept, :redirect_if_superceded, :instantiate_preferred_names
  before_filter :add_page_view_log_entry

  def show
    # TODO - On next line @curator is defined and doesn't seem to be used anywhere for maps tab. Remove it if not really needed.
    @curator = current_user.min_curator_level?(:full)
    @assistive_section_header = I18n.t(:assistive_maps_header)
    @watch_collection = logged_in? ? current_user.watch_collection : nil
    @maps = @taxon_concept.data_objects_from_solr({
      :page => 1,
      :per_page => 100,
      :data_type_ids => DataType.image_type_ids,
      :data_subtype_ids => DataType.map_type_ids,
      :ignore_translations => true
    })
    DataObject.preload_associations(@maps, [ :users_data_objects_ratings, { :data_objects_hierarchy_entries => :hierarchy_entry } ] )
    @rel_canonical_href = @selected_hierarchy_entry ?
      taxon_hierarchy_entry_maps_url(@taxon_concept, @selected_hierarchy_entry) :
      taxon_maps_url(@taxon_concept)
    current_user.log_activity(:viewed_taxon_concept_maps, :taxon_concept_id => @taxon_concept.id)
  end

end
