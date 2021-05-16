class Backend
  include Mongoid::Document

  field :proto, type: String
  field :balance, type: String, default: "roundrobin"

  embedded_in :route
  embeds_many :servers
  embeds_many :opts

end
