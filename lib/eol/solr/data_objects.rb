module EOL
  module Solr
    class DataObjects

      def self.search_with_pagination(taxon_concept_id, options = {})
        options[:page]        ||= 1
        options[:per_page]    ||= 30
        options[:per_page]      = 30 if options[:per_page] == 0

        response = solr_search(taxon_concept_id, options)
        total_results = response['response']['numFound']
        results = response['response']['docs']
        add_resource_instances!(results, options)

        results = WillPaginate::Collection.create(options[:page], options[:per_page], total_results) do |pager|
          pager.replace(results.collect{ |r| r['instance'] }.compact)
        end
        results
      end

      def self.add_resource_instances!(docs, options)
        includes = []
        selects = options[:preload_select] || { :data_objects => '*' }
        unless options[:skip_preload]
          includes = [ :hierarchy_entries, :toc_items ]
          selects[:hierarchy_entries] = '*'
          selects[:table_of_contents] = '*'
        end
        EOL::Solr.add_standard_instance_to_docs!(DataObject, docs, 'data_object_id',
          :includes => includes,
          :selects => selects)
      end
      
      def self.prepare_search_url(taxon_concept_id, options = {})
        url =  $SOLR_SERVER + $SOLR_DATA_OBJECTS_CORE + '/select/?wt=json&q=' + CGI.escape("{!lucene}ancestor_id:#{taxon_concept_id}")
        unless options[:published].nil?
          url << CGI.escape(" AND published:#{(options[:published]) ? 1 : 0}")
        end
        
        if options[:license_ids]
          url << CGI.escape(" AND (license_id:#{options[:license_ids].join(' OR license_id:')})")
        end
        
        if options[:toc_ids]
          url << CGI.escape(" AND (toc_id:#{options[:toc_ids].join(' OR toc_id:')})")
        end
        if options[:toc_ids_to_ignore]
          url << CGI.escape(" NOT (toc_id:#{options[:toc_ids_to_ignore].join(' OR toc_id:')})")
        end
        
        
        if options[:filter_hierarchy_entry] && options[:filter_hierarchy_entry].class == HierarchyEntry
          field_suffix = "ancestor_he_id"
          search_id = options[:filter_hierarchy_entry].id
          url << CGI.escape(" AND ancestor_he_id:#{search_id}")
          unless options[:return_hierarchically_aggregated_objects]
            url << CGI.escape(" AND hierarchy_entry_id:#{search_id}")
          end
        else
          field_suffix = "ancestor_id"
          search_id = taxon_concept_id
          unless options[:return_hierarchically_aggregated_objects]
            url << CGI.escape(" AND taxon_concept_id:#{search_id}")
          end
        end

        if options[:vetted_types] && !options[:vetted_types].include?('all')
          url << CGI.escape(" AND (")
          url << CGI.escape(options[:vetted_types].collect{ |t| "#{t}_#{field_suffix}:#{search_id}" }.join(' OR '))
          url << CGI.escape(")")
        end
        if options[:visibility_types] && !options[:visibility_types].include?('all')
          url << CGI.escape(" AND (")
          url << CGI.escape(options[:visibility_types].collect{ |t| "#{t}_#{field_suffix}:#{search_id}" }.join(' OR '))
          url << CGI.escape(")")
        end

        if options[:data_type_ids]
           # TODO: do we want to remove IUCN from this query?
          url << CGI.escape(" AND (data_type_id:#{options[:data_type_ids].join(' OR data_type_id:')})")
        else
           # IUCN types are very special in the system and should never be returned
          url << CGI.escape(" NOT (data_type_id:#{DataType.iucn.id})")
        end
        
        if options[:filter_by_subtype]
          if options[:data_subtype_ids]
            url << CGI.escape(" AND (data_subtype_id:#{options[:data_subtype_ids].join(' OR data_subtype_id:')})")
          else
            # these are all the objects with data_subtype_id = 0 OR NULL value in data_subtype
            url << CGI.escape(" AND (data_subtype_id:0 OR (*:* NOT data_subtype_id:[* TO *]))")
          end
        end
        
        if options[:user] && options[:user].class == User
          if options[:curated_by_user] === true
            url << CGI.escape(" AND curated_by_user_id:#{options[:user].id}")
          elsif options[:curated_by_user] === false
            url << CGI.escape(" NOT curated_by_user_id:#{options[:user].id}")
          end
          if options[:ignored_by_user] === true
            url << CGI.escape(" AND ignored_by_user_id:#{options[:user].id}")
          elsif options[:ignored_by_user] === false
            url << CGI.escape(" NOT ignored_by_user_id:#{options[:user].id}")
          end
        end
        
        if options[:resource_id]
          url << CGI.escape(" AND resource_id:#{options[:resource_id]}")
        end
        
        if options[:language_ids]
          nil_language_clause = "";
          if options[:allow_nil_languages]
            nil_language_clause = "OR (language_id:0 OR (*:* NOT language_id:[* TO *]))"
          end
          url << CGI.escape(" AND (language_id:#{options[:language_ids].join(' OR language_id:')} #{nil_language_clause})")
        end
        
        if options[:language_ids_to_ignore]
          url << CGI.escape(" NOT (language_id:#{options[:language_ids_to_ignore].join(' OR language_id:')})")
          unless options[:allow_nil_languages]
            url << CGI.escape(" AND language_id:[* TO *]")
          end
        end
        
        # ignoring translations means we will not return objects which are translations of other original data objects
        if options[:ignore_translations]
          url << CGI.escape(" NOT is_translation:true")
        end
        
        # add sorting
        if options[:sort_by] == 'newest'
          url << '&sort=data_object_id+desc'
        elsif options[:sort_by] == 'oldest'
          url << '&sort=data_object_id+asc'
        elsif options[:sort_by] == 'status'
          url << '&sort=max_visibility_weight+desc,max_vetted_weight+desc,data_rating+desc'
        else
          url << '&sort=data_rating+desc'
        end
        # we only need a couple fields
        url << "&fl=data_object_id,guid"
        
        if options[:facet_by_resource]
          url << '&facet.field=resource_id&facet.mincount=1&facet.limit=300&facet=on'
        end
        url
      end
      
      def self.solr_search(taxon_concept_id, options = {})
        url = prepare_search_url(taxon_concept_id, options)
        
        # add paging
        limit  = options[:per_page] ? options[:per_page].to_i : 10
        page = options[:page] ? options[:page].to_i : 1
        offset = (page - 1) * limit
        url << '&start=' << URI.encode(offset.to_s)
        url << '&rows='  << URI.encode(limit.to_s)
        # puts "\n\nThe SOLR Query: #{url}\n\n"
        res = open(url).read
        JSON.load res
      end
      
      def self.get_aggregated_media_facet_counts(taxon_concept_id, options = {})
        url =  $SOLR_SERVER + $SOLR_DATA_OBJECTS_CORE + '/select/?wt=json&q='
        url << CGI.escape("{!lucene}published:1 AND ancestor_id:#{taxon_concept_id} AND visible_ancestor_id:#{taxon_concept_id}")
        if options[:filter_hierarchy_entry] && options[:filter_hierarchy_entry].class == HierarchyEntry
          field_suffix = "ancestor_he_id"
          search_id = options[:filter_hierarchy_entry].id
          url << CGI.escape(" AND ancestor_he_id:#{options[:filter_hierarchy_entry].id}")
        else
          field_suffix = "ancestor_id"
          search_id = taxon_concept_id
        end
        
        options[:vetted_types] = ['trusted', 'unreviewed']
        options[:vetted_types] << 'untrusted' if options[:user] && options[:user].is_curator?
        url << CGI.escape(" AND (")
        url << CGI.escape(options[:vetted_types].collect{ |t| "#{t}_#{field_suffix}:#{search_id}" }.join(' OR '))
        url << CGI.escape(")")
        
        options[:data_type_ids] = DataType.image_type_ids + DataType.video_type_ids + DataType.sound_type_ids
        url << CGI.escape(" AND (data_type_id:#{options[:data_type_ids].join(' OR data_type_id:')})")
        # ignore maps
        url << CGI.escape(" NOT data_subtype_id:#{DataType.map.id}")
        url << CGI.escape(" NOT is_translation:true")
        
        # we only need a couple fields
        url << '&facet.field=data_type_id&facet=on&rows=0'
        res = open(url).read
        res = open(url).read
        response = JSON.load(res)
        facets = {}
        f = response['facet_counts']['facet_fields']['data_type_id']
        f.each_with_index do |rt, index|
          next if index % 2 == 1 # if its odd, skip this. Solr has a strange way of returning the facets in JSON
          data_type = DataType.find(rt.to_i)
          key = data_type.label('en').downcase
          facets[key] = f[index+1].to_i
        end
        facets['all'] = response['response']['numFound']
        
        facets["video"] ||= 0
        facets["video"] += facets["youtube"] if facets["youtube"]
        facets["video"] += facets["flash"] if facets["flash"]
        facets.delete("youtube")
        facets.delete("flash")
        facets.delete("gbif image")
        facets
      end
      
      def self.load_resource_facets(taxon_concept_id, options = {})
        url = prepare_search_url(taxon_concept_id, options)
        url << '&rows=0'
        res = open(url).read
        response = JSON.load res
        
        facets = []
        f = response['facet_counts']['facet_fields']['resource_id']
        f.each_with_index do |rt, index|
          next if index % 2 == 1 # if its odd, skip this. Solr has a strange way of returning the facets in JSON
          facets << { :resource_id => rt.to_i, :count => f[index+1].to_i }
        end
        
        # lookup associated resource instances
        if ids = facets.collect{ |f| f[:resource_id] }.compact
          resources = Resource.find_all_by_id(ids)
          facets.each do |f|
            if r = resources.detect{ |r| r.id == f[:resource_id] }
              f[:resource] = r
            end
          end
        end
        facets.delete_if{ |f| f[:resource].blank? }
        # facets << { :resource => nil, :all => true, :count => response['response']['numFound'] }
        facets
      end
      
      def self.get_facet_counts(taxon_concept_id)
        facets = {}
        base_url =  $SOLR_SERVER + $SOLR_DATA_OBJECTS_CORE + '/select/?wt=json&q=' + CGI.escape(%Q[{!lucene}])
        [true, false].each do |do_ancestor|
          ['trusted', 'unreviewed'].each do |vetted_status|
            url = base_url.dup + CGI.escape(%Q[published:1 AND #{vetted_status}_ancestor_id:#{taxon_concept_id} AND visible_ancestor_id:#{taxon_concept_id}])
            url << CGI.escape(" AND taxon_concept_id:#{taxon_concept_id}") unless do_ancestor
            url << '&facet.field=data_type_id&facet=on&rows=0'
            res = open(url).read
            response = JSON.load(res)
            f = response['facet_counts']['facet_fields']['data_type_id']
            key_prefix = vetted_status
            key_prefix = "ancestor_" + key_prefix if do_ancestor
            f.each_with_index do |rt, index|
              next if index % 2 == 1 # if its odd, skip this. Solr has a strange way of returning the facets in JSON
              data_type = DataType.find(rt.to_i)
              key = key_prefix + "_" + data_type.label('en').downcase
              facets[key] = f[index+1].to_i
            end
            facets['all'] = response['response']['numFound']
            
            facets[key_prefix + "_video"] ||= 0
            facets[key_prefix + "_video"] += facets[key_prefix + "_youtube"] if facets[key_prefix + "_youtube"]
            facets[key_prefix + "_video"] += facets[key_prefix + "_flash"] if facets[key_prefix + "_flash"]
            facets.delete(key_prefix + "_youtube")
            facets.delete(key_prefix + "_flash")
            facets.delete(key_prefix + "_gbif image")
          end
        end
        facets
      end
    end
  end
end
