require 'sinatra'
require 'sinatra-initializers'
require 'mongoid'
require "sinatra/config_file"

register Sinatra::Initializers
Mongoid.load!('config/mongoid.yml')
config_file 'config/config.yml'

get '/' do
  content_type :html
  "ICDC HAProxy API. Take look on <a href='https://git.icdc.io/icdc/haproxy_api'>README</a>\n"
end

namespace '/api/1' do

before do
  content_type :json, 'charset' => 'utf-8'
  apikey = request.env["HTTP_X_HAPROXYAPI_KEY"] || params[:key]
  unless ApiKey.all.collect{|x| x.value}.include?(apikey)
    logger.error "Attempt to authorize '#{request.ip}' with API key: '#{apikey}'"
    halt 401, {message: "Unauthourized. Use AUTH header to provide valid key"}.to_json
  end
  @apiv="/api/1"
  prepare
end


helpers do

def prepare
  @json = nil
  return unless ["POST","PUT"].include?(request.request_method)
  begin
    @json = JSON.parse(request.body.read)
  rescue Exception => e
    logger.error "Failed not parse request body: #{e.message}"
    halt 400, {message: e.message}.to_json
  end
end

def store
  begin
    ConfigManager.update(settings) unless Sinatra::Application.environment == :test
  rescue => e
    logger.error "Failed to make ConfigManager.update: #{e.message}"
    halt 500, {message: e.message}.to_json
  end
  status 200
  {}
end


WEB_ROUTE_PORT = {"http" => 80, "https" => 443}

def new_cfg
  # Generate new route
  r = Route.new(@json)
  return nil if r.nil? || r.host.nil?
  # TODO: We do not support other paths yet
  r.path = "/"
  # Web-route
  if is_web_route?(r)
    r.port = WEB_ROUTE_PORT[r.proto]
    #validate new cfg
    return r
  end
  # TCP-route
  if is_tcp_route?(r)
    r.port = get_tcp_port
    p r.port
    return r if r.port <= 9000
  end
  logger.warn "Invalid route data: #{r.to_json}"
  halt 400, {message: "Invalid route data"}.to_json
end

def is_web_route?(r)
  WEB_ROUTE_PORT.keys.include?(r.proto)
end

def is_uniq_route?(r)
  #If frontend is unique
  return !Route.where("proto":r.proto, "host": r.host, "path": r.path).exists?
end

def mongo_id
  params[:id].gsub(/[^a-z0-9]/,'')
end

def is_tcp_route?(r)
  r.proto == 'tcp'
end

def get_tcp_port
  busy_ports = Route.where("proto": "tcp" ).pluck("port")
  busy_ports.empty? ? 8000 : busy_ports.max + 1
end

def halt_if_not_found_cert!
  @cert = Cert.where(id: mongo_id).first
  unless @cert
    logger.error "Certificate '#{params[:id]}' not found"
    halt 404, { message: "Certificate not found" }.to_json
  end
end

def halt_if_not_found_route!
  @route = Route.where(id: mongo_id).first
  unless @route
    logger.error "Route '#{params[:id]}' not found"
    halt 404, { message: "Route not found" }.to_json
  end
end

def halt_if_not_found_node!
  @node = HaproxyNode.where(id: mongo_id).first
  unless @node
    logger.error "HaproxyNode '#{params[:id]}' not found"
    halt 404, { message: "HaproxyNode not found" }.to_json
  end
end

end

## Certificates

post '/certs' do
  cert = Cert.new(@json)
  if cert.save
    store
    response.headers['Location'] = "#{request.base_url}#{@apiv}/certs/#{cert.id}"
    status 201
    logger.info "User [#{cert.owner}] added new SSL-certificate [#{cert.name}] for domains #{cert.domains.to_s}"
  else
    status 422
    logger.error "Failed to store cert. Input: #{@json}"
    logger.error "Failed to store cert. Output: #{cert.to_json}"
    body cert.to_json
  end
end

get '/certs' do
  ac = Cert.all 
  [:owner, :domain].each do |filter|
    ac = Cert.send(filter, params[filter]) if params[filter]
  end
  ac.to_json(:except => [:errors, :updated_at])
end


get '/certs/:id' do
  halt_if_not_found_cert!
  @cert.to_json(:except => [:errors, :updated_at])
end

put '/certs/:id' do
  halt_if_not_found_cert!
  #TODO: modify
  halt 405, {message: "Not implemented yet"}.to_json
end

delete '/certs/:id' do
  halt_if_not_found_cert!
  logger.info "User #{@cert.owner} removed new SSL-certificate #{@cert.name} for domains #{@cert.domains.to_s}"
  @cert.destroy
  store
  status 204 #No Content
end

## Route API

get "/routes" do
  ar = Route.all
  [:service, :proto].each do |filter|
    ar = Route.send(filter, params[filter]) if params[filter]
  end
  ar.to_json(:except => [:errors, :updated_at])
end

get "/routes/:id" do
  halt_if_not_found_route!
  @route.to_json
end

put '/routes/:id' do
  halt_if_not_found_route!
  @config = new_cfg
  @config.id = @route.id
  begin
    @route.delete
    @config.save!
  rescue => e
    logger.error "Failed to update route: #{e.message}"
    halt 500, {message: "Failed to update route"}.to_json
  end
  logger.info "Route updated: #{@json}"
  store
  @config.to_json
end

put '/routes/:id/suspend' do
  halt_if_not_found_route!
  @route.security.status = "suspended"
  unless @route.save
    logger.error "Failed to suspend route '#{params[:id]}' cause: #{e.message}"
    halt 500, {message: "Failed to suspend route"}.to_json
  end
  logger.info "Route suspended: #{@route.to_json}"
  store
  @route.to_json
end

put '/routes/:id/set-path' do
  halt_if_not_found_route!
  if (!is_web_route?(@route))
    logger.error "Could not set-path '#{@json}' for TCP route '#{params[:id]}'"
    halt 500, {message: "Could not set-path for TCP route"}.to_json
  end
  path = @json["path"]
  opt = Opt.new(name: "http-request", value: "set-path #{path}")
  @route.backend.opts.push(opt)
  unless @route.save
    logger.error "Failed to set-path '#{path}' for route '#{params[:id]}' cause: #{e.message}"
    halt 500, {message: "Failed to set-path for route"}.to_json
  end
  logger.info "set-path for route updated: #{@route.to_json}"
  store
  @route.to_json
end

post '/routes' do
  @config = new_cfg
  unless is_uniq_route?(@config)
    logger.warn "Duplicated route: #{@config.to_json}"
    halt 409, {message: "Route already exists"}.to_json
  end
  #FIX: apply frequent auto update make cause performance issues
  begin
    @config.save!
  rescue => e
    logger.error "Failed to add route: #{@config.to_json}"
    halt 500, {message: "Failed to add route"}.to_json
  end
  logger.info "Route added: #{@json}"
  store
  @config.to_json
end

delete '/routes/:id' do
  halt_if_not_found_route!
  logger.info "Route deleted: #{@route.to_json}"
  route_data = @route.to_json #FIX: remove when lotus integration will be fixed
  @route.delete
  store
  status 200                  #FIX: revert to 204, when deploy permanent fix for lotus integration
  #status 204 #No Content
  route_data                  #FIX: temporary fix to send data to lotus integration
end

delete '/routes' do
  ar = Route.all
  [:service].each do |filter|
    ar = Route.send(filter, params[filter]) if params[filter]
  end
  routes_data = ar.to_json
  if ar.any?
    logger.info "Routes deleted: #{routes_data}"
    ar.delete_all
  end
  store
  #status 204 #No Countent
  status 200
  routes_data
end

## Push updates

post '/store' do
  store
end

## HAproxy Node API

get '/nodes' do
  HaproxyNode.all.to_json
end

post '/nodes' do
  n = HaproxyNode.new(@json)
  begin
    n.save!
  rescue => e
    logger.error "Failed to add haproxy_node: #{@n.to_json}"
    halt 500, {message: "Failed to add haproxy_node: #{e.message}"}.to_json
  end
  n.to_json
end

get '/nodes/:id' do
  halt_if_not_found_route!
  @node.to_json
end

delete '/nodes/:id' do
  halt_if_not_found_route!
  @node.delete
  status 204
end

##############################################
# OBSOLETE:
## Special ManageIQ integration, by service_id
get "/service/:id" do
  r = Route.where("service_id": params[:id].to_i)
  r.to_json
end

delete '/service/:id' do
  logger.info "Delete all routes for service: #{params[:id]}"
  Route.where("service_id": params[:id].to_i).delete_all
  store
  status 204 #No Content
end
##############################################

end

