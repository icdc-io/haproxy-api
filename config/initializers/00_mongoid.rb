module Mongoid
 module Serializable
   def serializable_hash(options={})
     attrs = super(options)
     attrs["id"] = attrs.delete("_id").to_s
     attrs
   end
 end
end

