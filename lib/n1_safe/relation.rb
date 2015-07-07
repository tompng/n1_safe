module N1Safe::Relation
# ActiveRecord::Relation.class_eval do
  def n1_safe_set root: nil, path: nil, parent: nil
    @n1_safe = {root: root, parent: parent, path: path}
    self
  end

  def n1_safe
    root = N1Safe::Preloader.new self
    n1_safe_set root: root
  end

  def n1_safe_info
    @n1_safe
  end

  def n1_safe?
    !!@n1_safe
  end

  def n1_safe_preload
    return if @n1_safe_preloaded
    @n1_safe_preloaded = true
    hoge=@n1_safe
    @n1_safe=nil
    hoge[:root].preload hoge[:path]
    load
    load_target.map{|s|
      s.n1_safe_set root: hoge[:root], path: hoge[:path], parent: hoge[:parent]
    }
    @n1_safe = hoge
  end

  %i(to_a to_ary first second third fourth fifth).each do |name|
    define_method name do |*args, &block|
      return super *args, &block unless @n1_safe
      n1_safe_preload if @n1_safe
      load_target.send name, *args, &block
    end
  end

  def size
    n1_safe_preload if @n1_safe
    super
  end

  def count *args, &block
    return super unless @n1_safe
    *parent_path, name = @n1_safe[:path]
    @n1_safe[:root].count(@n1_safe[:parent], parent_path, name) || to_a.size
  end

end
