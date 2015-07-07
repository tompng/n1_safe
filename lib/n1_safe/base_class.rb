module N1Safe::BaseClass
  def n1_safe_module
    unless @n1_safe_module
      @n1_safe_module = Module.new
      prepend @n1_safe_module
    end
    @n1_safe_module
  end


  def n1_safe_define name, multiple: false
    n1_safe_module.send :define_method, name do
      return super() unless @n1_safe
      if @n1_safe
        n1_safe_preload name unless multiple# unless association(name).loaded?
        child = super()
        child.n1_safe_set root: @n1_safe[:root], path: [*@n1_safe[:path], name], parent: self if child
      end
    end
  end

  def has_many name, *args
    n1_safe_define name, multiple: true
    super
  end
  def has_one name, *args
    n1_safe_define name
    super
  end
  def belongs_to name, *args
    n1_safe_define name
    super
  end
end