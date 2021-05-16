require 'sinatra/base'
require 'securerandom'
require 'json'
require 'open3'

module HaproxyHelper
  def self.generate_names(config)
    backend_title = ""
    config["backends"].each do |backend|
      backend["title"] = p SecureRandom.urlsafe_base64(6)
      backend_title = backend["title"]
        backend["servers"].each do |server|
          server["name"] = p SecureRandom.urlsafe_base64(6)
        end
      end
    config["frontends"].each do |frontend|
      frontend["title"] = p SecureRandom.urlsafe_base64(6)
      frontend["default_backend"] = backend_title
    end
    config
    end

  def self.reload
    make_log, status = Open3.capture3("service haproxy restart")
    hash = { log: make_log, status: status}
    json = JSON.generate(hash)
  end
end


