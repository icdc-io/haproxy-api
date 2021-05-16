require 'bundler/setup'
Bundler.require(:default)

Sinatra::Application.set(
  environment: ENV['RACK_ENV'].to_sym || :development,
  run: false
)

before {
  if Sinatra::Application.environment == :production
    env['rack.logger'] = Logger.new( File.join('log','audit.log') )
  end
}

#configure do
#  mongo_config = YAML::load_file(File.join(__dir__, 'config', 'mongo.yml'))
#  MongoMapper.setup(mongo_config, Sinatra::Application.environment)
#end

Dir["./models/*.rb"].each {|file| require file }
require './app'

run Sinatra::Application
