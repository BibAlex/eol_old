# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_migration_session',
  :secret      => '01b8da42fecf48cf3a8f7a085f7e1607e43ba958ec8bed87ce3f94341760df5efd3237b8b06898bac70ec25aa8d295b1cb969c2416fb6747b0028b220cf91b42'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
