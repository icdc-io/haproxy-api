require 'securerandom'

class ApiKey
  include Mongoid::Document

  field :value, type: String

  def initialize(options={})
    options[:value] = options[:value] || SecureRandom.uuid
    super(options)
  end
end

