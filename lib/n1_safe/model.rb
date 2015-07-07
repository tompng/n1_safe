module N1Safe::Model
  include N1Safe::Methods

  def n1_safe_set root: nil, path: nil, parent: nil
    root ||= ::N1Safe::Preloader.new [self]
    path ||= []
    @n1_safe = {root: root, path: path, parent: parent}
    self
  end

  def n1_safe_preload name
    without_n1_safe do |n1_safe|
      n1_safe[:root].preload [*n1_safe[:path], name]
    end
  end
end
