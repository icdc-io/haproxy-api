class Security
  include Mongoid::Document

  field :status, type: String
  field :purpose, type: String

  embedded_in :route
  embeds_one :project

end
