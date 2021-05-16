class Server
  include Mongoid::Document

  field :name, type: String
  field :host, type: String
  field :port, type: Integer
  field :weight, type: Integer

  validates :weight, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 256 }, allow_nil: true

  embedded_in :backend
  embeds_many :opts
  
end
