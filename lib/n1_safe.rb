module N1Safe
end

require_relative 'n1_safe/model'
require_relative 'n1_safe/preloader'
require_relative 'n1_safe/collection'

ActiveRecord::Base.singleton_class.class_eval do
  def n1_safe
    all.n1_safe
  end
end

ActiveRecord::Base.class_eval do
  def n1_safe
    root = N1Safe::Preloader.new [self]
    N1Safe::Model.new root, self, []
  end
end

ActiveRecord::Relation.class_eval do
  def n1_safe
    root = N1Safe::Preloader.new to_a
    N1Safe::Collection.new root, self, [], nil
  end
end

Array.class_eval do
  def n1_safe
    root = N1Safe::Preloader.new self
    N1Safe::Collection.new root, self, [], nil
  end
end
