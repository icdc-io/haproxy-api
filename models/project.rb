class Project
  include Mongoid::Document

  field :code, type: String
  field :name, type: String
  
  embedded_in :security

end
