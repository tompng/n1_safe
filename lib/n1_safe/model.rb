module N1Safe::Model
  def n1_safe
    n1_safe_set
  end

  def n1_safe_info
    @n1_safe
  end

  def n1_safe?
    !!@n1_safe
  end

  def n1_safe_set root: nil, path: nil, parent: nil
    root ||= ::N1Safe::Preloader.new [self]
    path ||= []
    @n1_safe = {root: root, path: path, parent: parent}
    self
  end

  def n1_safe_preload name
    path = [*@n1_safe[:path], name]
    hoge = @n1_safe
    @n1_safe = nil
    hoge[:root].preload path
    child = send name
    child.n1_safe_set root: hoge[:root], path: path, parent: self if child
    @n1_safe = hoge
    child
  end
end
