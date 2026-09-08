ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "dotenv"

# Local credentials belong in .env.local, which is ignored by Git. Dotenv does
# not override values provided by the shell or deployment environment.
if ENV.fetch("RAILS_ENV", "development") != "production"
  Dotenv.load(File.expand_path("../.env.local", __dir__))
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
