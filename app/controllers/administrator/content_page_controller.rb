class Administrator::ContentPageController < AdminController

  layout 'left_menu'

  before_filter :set_layout_variables

  access_control :DEFAULT => 'Administrator - Site CMS'
  
 def index
   @page_title = 'Edit Page Contents'
   @content_sections = ContentSection.find(:all, :order => 'name')
   @content_section_id = params[:content_section_id] || @content_sections[0].id
   @content_section = ContentSection.find(@content_section_id)
   # get the content pages for the selected section or the first section
   @content_pages = ContentPage.find_all_by_content_section_id(@content_section_id, :order => 'sort_order, language_abbr')
   # show the selected page or the first page in the selection section
   content_page_id = params[:content_page_id] || @content_pages[0].id
   # get the page content for the selected (or first) page
   @page = ContentPage.find(content_page_id)
 end
  
 def update
   old_page = ContentPage.find(params[:id])
   page = ContentPage.update(params[:id], params[:page])
   page.update_attribute(:last_update_user_id, current_user.id)
   if page.valid?
     ContentPageArchive.backup(old_page) # backup old page
     expire_menu_caches(page)
     flash[:notice] = 'Content has been updated.'
   else
     flash[:error] = 'Some required fields were not entered (you must enter a title, and content OR a URL).'
   end
   redirect_to :action => 'index', :content_section_id => page.content_section.id, :content_page_id => page.id
 end
 
 # pull the updated content from the querystring to build the preview version of the page 
 def preview
   @content = ContentPage.new(params[:page])
   render :layout => 'admin_without_nav'
 end
 
 def create
   @content_section_id = params[:id]
   new_page = create_new_page(@content_section_id) 
   expire_menu_caches
   redirect_to :action => 'index', :content_section_id => new_page.content_section.id, :content_page_id => new_page.id, :new_page => 'true'
 end

 def destroy
   (redirect_to :action => 'index';return) unless request.method == :delete
   current_page = ContentPage.find(params[:id])
   current_page.last_update_user_id = current_user.id   
   ContentPageArchive.backup(current_page) # backup page   
   content_section_id = current_page.content_section_id
   current_page.destroy
   redirect_to :action => 'index', :content_section_id => content_section_id
 end
 
 # AJAX CALLs
 def get_content_pages
    # get the content pages for the content section ID passed in the querystring parameter
    @content_section_id = params[:id]
    @content_section = ContentSection.find(@content_section_id)
    @content_pages = ContentPage.find_all_by_content_section_id(@content_section_id, :order => 'sort_order, language_abbr')
    # get the first page in that section if we have pages
    if @content_pages.size>0 
      @page = ContentPage.find(@content_pages[0]) 
    else # otherwise redirect to create a new page (the first) in this section
      @page = create_new_page(@content_section_id) 
    end
    render :update do |page|
      page.replace_html 'content_page_list', :partial => 'content_page_list'
      page.replace_html 'content_page', :partial => 'form'
    end   
 end
 
  def get_page_content
    # get the specific page for the page ID passed in by the ID querystring parameter
    @page = ContentPage.find(params[:id], :include => :content_page_archives)
    render :update do |page|
      page.replace_html 'content_page', :partial => 'form'
    end  
 end
 
 def get_archive_page_content
    # get the specific archived page for the page ID  & archieve ID using the querystring parameters
    @page = ContentPage.find(params[:page_id], :include => :content_page_archives)
    @archived_page = ContentPageArchive.find_by_id_and_content_page_id(params[:archieve_id],params[:page_id])
    @page.title = @archived_page.title
    @page.page_name = @archived_page.page_name
    @page.left_content = @archived_page.left_content
    @page.main_content = @archived_page.main_content
    @page.created_at = @archived_page.created_at
    render :update do |page|
      page.replace_html 'content_page', :partial => 'form'
    end  
 end
 
private 

  def create_new_page(content_section_id)
    new_page = ContentPage.new
    new_page.page_name = 'New Page'
    new_page.title = 'New Page'
    new_page.active = false
    new_page.url = ''
    new_page.main_content = 'Content goes here'
    new_page.left_content = ''
    new_page.content_section_id = content_section_id
    new_page.sort_order = 99
    new_page.save
    return new_page
  end
  
  def set_layout_variables
    @page_title = $ADMIN_CONSOLE_TITLE
    @navigation_partial = '/admin/navigation'
  end

end
