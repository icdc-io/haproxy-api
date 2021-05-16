require 'net/sftp'
require 'stringio'

class HaproxyNode
  include Mongoid::Document

  field :name, type: String
  field :host, type: String
  field :port, type: Integer
  field :user, type: String
  field :config_dir, type: String
  field :cert_dir, type: String

  validates :name, presence: true
  validates :host, presence: true
  before_save :set_defaults

  #TODO: Refactor using single SFTP connection for all actions

  def put(&blk)
    Net::SFTP.start(self.host, self.user, port: self.port, auth_methods: ["publickey"]) do |sftp|
       files = yield
       files.each do |file|
         sftp.upload!( StringIO.new(file[:content]), file[:name])
       end
    end
  end

  def list(dir_path)
    filenames = []
    Net::SFTP.start(self.host, self.user, port: self.port, auth_methods: ["publickey"]) do |sftp|
      sftp.dir.foreach(dir_path) do |entry|
        filenames.push(entry.name)
      end
    end
    return filenames
  end

  def remove_files(&blk)
    Net::SFTP.start(self.host, self.user, port: self.port, auth_methods: ["publickey"]) do |sftp|
      files = yield
      files.each do |file|
        sftp.remove(file)
      end
    end
  end
  
private

  def set_defaults
    self.name = self.name.parameterize.underscore
    self.port ||= 22
    self.user ||= 'haproxy'
    self.config_dir = (self.config_dir || "/etc/haproxy").tr(';$`&|','')
    self.cert_dir = (self.cert_dir || "/etc/ssl/private").tr(';$`&|','')
  end

end
