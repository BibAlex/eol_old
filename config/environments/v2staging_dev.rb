# Settings specified here will take precedence over those in config/environment.rb
# 1) config/environment.rb
# 2) config/environments/[RAILS_ENV].rb
# 3) config/environments/[RAILS_ENV]_eol_org.rb
# 4) config/environment_eol_org.rb

# Allow breakpoints in mongrel:
require "ruby-debug"

config.whiny_nils = true
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching = false
config.action_view.debug_rjs = false
config.cache_classes = false
config.cache_store = :mem_cache_store
config.action_mailer.raise_delivery_errors = false

config.log_level = :debug # :error
if ENV['RAILS_ENV'] == 'v2staging_dev'
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActionController::Base.logger = Logger.new(STDOUT)
  ActiveSupport::Cache::MemCacheStore.logger = Logger.new(STDOUT)
end

$PARENT_CLASS_MUST_USE_MASTER = ActiveRecord::Base
$LOG_USER_ACTIVITY = true
$EXCEPTION_NOTIFY = true
$ERROR_LOGGING = true
$ENABLE_ANALYTICS = false
$ENABLE_RECAPTCHA = false
$LOG_WEB_SERVICE_EXECUTION_TIME = true
$USE_SSL_FOR_LOGIN=false
$SKIP_URL_VALIDATIONS = true

# Override some values and add new ones with private information included
begin
  require File.join(File.dirname(__FILE__), 'v2staging_dev_private')
rescue LoadError
  puts '*************WARNING: COULD NOT LOAD v2staging_dev_private FILE***********************'
end
