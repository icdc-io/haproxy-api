require 'openssl'
require 'openssl-extensions/all'
require 'base64'

class Cert
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :owner, type: String
  field :cert, type: String
  field :key, type: String
  field :ca, type: String
  field :not_before, type: Time
  field :not_after, type: Time
  field :domains, type: Array
  field :filename, type: String

  validates :name, presence: true
  validates :owner, presence: true
  validates :cert, presence: true
  validates :filename, uniqueness: true

  scope :owner, -> (userid) { where(owner: userid) }

  before_validation :extract_cert_info

  def self.valid_certs
    Cert.where(:not_before.lt => Time.now, :not_after.gt => Time.now)
  end

  def as_json(options={})
    options[:except] = options[:except] || []
    options[:except].concat([:key,:cert,:ca,:filename])
    h = super(options)
    h[:errors] = errors unless options[:except] && options[:except].include?("errors")
    h[:expired] = !(self.not_before && self.not_before < Time.now && self.not_after && self.not_after > Time.now)
    h
  end

  def self.domain(domain)
    d = []
    self.valid_certs.each do |cert|
       d << cert unless cert.match(domain).nil?
    end
    d
  end

  def match(check_domain)
    self.domains.each do |domain|
      if is_wildcard?(domain)
        wildcard_pattern = domain.gsub(/\./,"\\.").gsub( /^\*/, "^[^\\.]*" )
        wildcard_pattern = %r[#{wildcard_pattern}]
        # Match only single-level wildcards, example:
        # domain = *.icdc.io
        # wildcard_pattern = ^[^\.]*\.icdc\.io
        # 1.) check_domain = test.icdc.io //Conflict
        # 2.) check_domain = data.test.icdc.io //No conflict
        return domain unless wildcard_pattern.match(check_domain).nil?
      elsif check_domain == domain
        return domain
      end
    end
    return nil
  end

private 

  def get_input_cert(data)
    #We have to clear and convert data, so Ruby OpenSSL library be able to consume it
    # 1. Certificates come encoded in base64
    data = Base64.decode64(data).encode!(Encoding::UTF_8)
    # 2. Remove whitespaces in the beggining and ends of each line
    #critical for -----BEGIN\END CERTIFICATE---- sections
    #internal spaces sefaely accepted by Ruby OpenSSL gem
    data = data.gsub(/^\s+/,'').gsub(/\s+$/,'')
    return data
  end

  def extract_cert_info
    begin
      c = OpenSSL::X509::Certificate.new(get_input_cert(self.cert))
      self.cert = c.to_pem
      k = OpenSSL::PKey.read(get_input_cert(self.key))
      self.key = k.to_pem
      if self.ca && !self.ca.empty?
        ca = OpenSSL::X509::Certificate.new(get_input_cert(self.ca))
        self.ca = ca.to_pem
      end
    rescue => e
      errors.add(:cert, "Could not parse data for certificates or key")
      return
    end
    self.not_before = c.not_before
    self.not_after = c.not_after
    unless c.check_private_key(k)
      errors.add(:key, "Bad key for the certificate")
      return
    end
    # Good certificate has list of domains in SAN:
    # https://stackoverflow.com/questions/5935369/ssl-how-do-common-names-cn-and-subject-alternative-names-san-work-together
    # Example: [ *.icdc.io, icdc.io ]
    self.domains = c.subject_alternative_names #all valid domains for this certififcate
    # Self-signed certificates store name in Subject only after CN=*.icdc.io
    if cn_match = /CN=(?<domain>[\*]?[\.\-a-z0-9]+)/.match(c.subject.to_s)
      cn_domain = cn_match[:domain]
      self.domains = (self.domains + [ cn_domain ]).uniq unless cn_domain.nil?
    end
    if self.domains.empty?
      errors.add(:domains, "Certificate does not provide any domain name")
      return
    end
    #generate unique filename
    if self.filename.nil? or self.filename.empty?
      self.filename = "#{Time.current.strftime("%Y%m%dT%H%M%S")}_#{self.domains.first.parameterize.underscore.to_sym}.pem"
    end
    # HAproxy takes certificates from /etc/ssl/private/ directory in filename order
    # 1.) conflict for two certificates for the same specific domain name: first certificate takes precedence
    # 2.) conflict for specific domain cert and wildcard cert: specific certificate prefers over wildcard
    # 3.) conflict for specific base domain (icdc.io) cert and wildcard cert (*.icdc.io, icdc.io): TBD
    self.class.valid_certs.each do |prev_cert|
      self.domains.select{|d| !is_wildcard?(d)}.each do |domain|
        matched_domain = prev_cert.match(domain)
        if !matched_domain.nil? && matched_domain != domain #specific domain match
          errors.add(:domains, "Certificate for domain '#{domain}' conflicts with existing wildcard certificate")
          return
        end
      end
    end
  end

  def is_wildcard?(s)
    !(/^\*\./.match(s).nil?)
  end

end

