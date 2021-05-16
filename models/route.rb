class Route
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :proto, type: String
  field :host, type: String
  field :port, type: Integer
  field :path, type: String
  field :service_id, type: Integer
  ## Outdated - Replaced with Security object
  field :approve_status, type: String
  field :project, type: String
  field :purpose, type: String
  ############################

  embeds_one :backend
  embeds_one :security

  scope :service, -> (serviceid) { where(service_id: serviceid.to_i) }
  scope :proto, -> (proto) { where(proto: proto) }
  scope :ready, -> (proto) { where(proto: proto, "security.status": "approved") }
end
