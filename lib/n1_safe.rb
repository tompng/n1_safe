module N1Safe
end

require_relative 'n1_safe/methods'
require_relative 'n1_safe/model'
require_relative 'n1_safe/preloader'
require_relative 'n1_safe/base_class'
require_relative 'n1_safe/relation'

ActiveRecord::Base.singleton_class.class_eval do
  prepend N1Safe::BaseClass
  def n1_safe
    all.n1_safe
  end
end


ActiveRecord::Base.class_eval do
  prepend N1Safe::Model
end

ActiveRecord::Associations::CollectionProxy.class_eval do
  prepend N1Safe::Relation
  def records_without_n1_safe
    load_target
  end
end

ActiveRecord::Relation.class_eval do
  prepend N1Safe::Relation
  def records_without_n1_safe
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
