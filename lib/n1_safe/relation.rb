module N1Safe::Relation
  include N1Safe::Methods

  def n1_safe_set root: nil, path: nil, parent: nil
    root ||= N1Safe::Preloader.new self
    path ||= []
    @n1_safe = {root: root, parent: parent, path: path}
    self
  end

  def n1_safe_preload
    return if @n1_safe_preloaded
    @n1_safe_preloaded = true
    without_n1_safe do |n1_safe|
      n1_safe[:root].preload n1_safe[:path]
      records_without_n1_safe.map{|child|child.n1_safe_set n1_safe}
    end
  end

  %i(to_a to_ary last first second third fourth fifth).each do |name|
    define_method name do |*args, &block|
      return super *args, &block unless n1_safe?
      n1_safe_preload if n1_safe?
      records_without_n1_safe.send name, *args, &block
    end
  end

  def size
    n1_safe_preload if n1_safe?
    super
  end

  def count *args, &block
    return super unless n1_safe?
    *parent_path, name = @n1_safe[:path]
    @n1_safe[:root].count(@n1_safe[:parent], parent_path, name) || to_a.size
  end
end
