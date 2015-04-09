module N1Safe
end

require_relative 'n1_safe/model'
require_relative 'n1_safe/preloader'
require_relative 'n1_safe/relation'

ActiveRecord::Base.singleton_class.class_eval do
  define_method :n1_safe do
    all.n1_safe
  end
end

ActiveRecord::Base.class_eval do
  define_method :n1_safe do
    root = N1Safe::Preloader.new [self]
    N1Safe::Model.new root, self, []
  end
end

ActiveRecord::Relation.class_eval do
  define_method :n1_safe do
    root = N1Safe::Preloader.new to_a
    N1Safe::Relation.new root, self, [], nil
  end
end
