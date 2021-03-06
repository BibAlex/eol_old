unless data_object.blank?
  xml.dataObject do
    xml.dc :identifier, data_object.guid
    xml.dataType data_object.data_type.schema_value
    
    unless minimal
      xml.mimeType data_object.mime_type.label unless data_object.mime_type.blank?
      
      for ado in data_object.agents_data_objects
        if ado.agent
          xml.agent ado.agent.full_name, :homepage => ado.agent.homepage, :role => ado.agent_role.label.downcase
        end
      end
      
      xml.dcterms :created, data_object.object_created_at unless data_object.object_created_at.blank?
      xml.dcterms :modified, data_object.object_modified_at unless data_object.object_modified_at.blank?
      xml.dc :title, data_object.object_title unless data_object.object_title.blank?
      xml.dc :language, data_object.language.iso_639_1 unless data_object.language.blank?
      xml.license data_object.license.source_url unless data_object.license.blank?
      xml.dc :rights, data_object.rights_statement unless data_object.rights_statement.blank?
      xml.dcterms :rightsHolder, data_object.rights_holder unless data_object.rights_holder.blank?
      xml.dcterms :bibliographicCitation, data_object.bibliographic_citation unless data_object.bibliographic_citation.blank?
      # leaving out audience
      xml.dc :source, data_object.source_url unless data_object.source_url.blank?
    end
    
    data_object.info_items.each do |ii|
      xml.subject ii.schema_value unless ii.schema_value.blank?
    end
    
    unless minimal
      xml.dc :description, data_object.description unless data_object.description.blank?
      xml.mediaURL data_object.object_url unless data_object.object_url.blank?
      xml.mediaURL DataObject.image_cache_path(data_object.object_cache_url, :orig) unless data_object.object_cache_url.blank?
      xml.thumbnailURL DataObject.image_cache_path(data_object.object_cache_url, '98_68') unless data_object.object_cache_url.blank?
      xml.location data_object.location unless data_object.location.blank?
      
      unless data_object.latitude == 0 && data_object.longitude == 0 && data_object.altitude == 0
        xml.geo :Point do
          xml.geo :lat, data_object.latitude unless data_object.latitude == 0
          xml.geo :long, data_object.longitude unless data_object.longitude == 0
          xml.geo :alt, data_object.altitude unless data_object.altitude == 0
        end
      end
      
      data_object.published_refs.each do |r|
        xml.reference r.full_reference
      end
    end
    
    xml.additionalInformation do
      xml.vettedStatus data_object.association_with_best_vetted_status.vetted.label if data_object.association_with_best_vetted_status
      xml.dataRating data_object.data_rating
    end
  end
end
