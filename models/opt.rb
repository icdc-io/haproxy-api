class Opt
  include Mongoid::Document

  field :name, type: String
  field :value, type: String
  
  embedded_in :backend
  embedded_in :server
end
