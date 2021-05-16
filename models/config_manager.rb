require 'json'
require 'sinatra'
require 'net/ssh'

class ConfigManager
  
  CFG_REMOTE = "/etc/haproxy/router.cfg".freeze
  CERT_REMOTE = "/etc/ssl/private/".freeze

  PROTOS = ["http", "https", "tcp"].freeze
  
  RELOAD_METHODS = {
    :service => "systemctl reload haproxy.service",
    :docker => "docker kill -s HUP haproxy",
    :podman => "podman kill -s HUP haproxy"
  }.freeze

  attr_accessor :views, :cfg_local

  def initialize(app_config)
    # We make this paths are configurable attributes,
    # because RSpec modifies settins.views and we can not use it anymore to determine paths in tests
    # So we modify this properties in RSpec tests
    @views = Sinatra::Application.settings.views
    @cfg_local = File.join(@views, "router.cfg")
    @reload_command = RELOAD_METHODS[app_config.haproxy_reload.to_sym]
  end

  def self.update(app_config)
    m = ConfigManager.new(app_config)
    m.generate_config
    m.save_certs
    m.deploy_config
  end

  def deploy_config
    #Push config and check consistency config for all nodes
    sum = nil
    HaproxyNode.all.each do |node|
      cfgsum = push_config(node)
      next if cfgsum == sum
      if sum.nil?
        sum = cfgsum
      else
        raise ScriptError, {error:"Config is not consistent for node: #{node.name}, sum - #{sum}, cfgsum - #{cfgsum}"}.to_json
      end
    end
    #Reload haproxy.service
    HaproxyNode.all.each do |node|
      reload_haproxy(node)
    end
  end

  def generate_config
    f = File.open(@cfg_local, "w")
    PROTOS.each { |proto| save_router(f, proto) }
    f.close
  end


  def save_certs
    HaproxyNode.all.each do |node|
      node.put do
        Cert.valid_certs.collect do |cert|
          {
            name: "#{CERT_REMOTE}#{cert.filename}",
            content: "#{cert.key}#{cert.cert}#{cert.ca}" #concat Key, Certificate and then Ca-Chain
          }
        end
      end
      #Remove old certificates
      cert_to_remove = []
      valid_cert_names = Cert.valid_certs.collect{|c| c.filename}
      node.list(CERT_REMOTE).each do |node_cert|
        next unless /\d{8}T\d{6}_.*\.pem/.match(node_cert) #take only auto-generated filenames 20180701T180503_domain_name.pem
        unless valid_cert_names.include?(node_cert)
          cert_to_remove.push(node_cert)
        end
      end
      node.remove_files do
        #prepare list of absolute filenames to delete
        cert_to_remove.collect{|filename| "#{CERT_REMOTE}#{filename}"}
      end
    end
  end

private

  def push_config(node)
    %x[rsync #{@cfg_local} #{node.user}@#{node.host}:#{CFG_REMOTE}]
    hashsum = %x[ssh #{node.user}@#{node.host} md5sum #{CFG_REMOTE} | cut -c1-32]
    hashsum.chomp
  end

  def reload_haproxy(node)
    output = %x[ssh #{node.user}@#{node.host} #{@reload_command}]
    output
  end

  def save_router(f, proto)
    @cfg = Route.ready(proto)
    template_file = File.join(@views, "router_#{proto}.cfg.erb")
    if File.exist?(template_file)
      template = ERB.new(File.read(template_file), nil, "-")
      content = template.result(binding)
      f.write(content)
    end
  end

end
