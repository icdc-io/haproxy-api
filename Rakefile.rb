require 'bundler'
require 'sinatra'
require 'mongoid'
Dir["./models/*.rb"].each {|file| require file }

ENV['RACK_ENV'] = ENV['RACK_ENV'] || "development"
Mongoid.load!('config/mongoid.yml')

namespace :db do
  task :migrate_20180706 do
    Route.each do |r|
      r.security = Security.new(
        status: r.approve_status,
        project: Project.new(
          name: r.project
        ),
        purpose: r.purpose
      )
      r.save!
    end
  end
end
