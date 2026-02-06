require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.cache_classes = true
  config.action_controller.perform_caching = false
  config.action_controller.allow_forgery_protection = false
end
