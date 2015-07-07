module N1Safe
end

require_relative 'n1_safe/model'
require_relative 'n1_safe/preloader'
require_relative 'n1_safe/base_class'
require_relative 'n1_safe/relation'

ActiveRecord::Base.singleton_class.class_eval do
  prepend N1Safe::BaseClass
end


ActiveRecord::Base.class_eval do
  prepend N1Safe::Model
  def n1_safe
    n1_safe_set
  end
end

ActiveRecord::Associations::CollectionProxy.class_eval do
  prepend N1Safe::Relation
end

ActiveRecord::Relation.class_eval do
  prepend N1Safe::Relation
  def load_target
    load
    @records
  end
end

Array.class_eval do
  def n1_safe
    root = N1Safe::Preloader.new self
    each{|record|record.n1_safe_set root: root}
    self
  end
end
