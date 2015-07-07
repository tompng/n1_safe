module N1Safe::BaseClass
  def n1_safe_define_association name, multiple: false
    original_method = "#{name}_without_n1_safe"
    define_method "#{name}_with_n1_safe" do
      return send original_method unless n1_safe?
      if @n1_safe
        n1_safe_preload name unless multiple
        child = send original_method
        child.n1_safe_set root: @n1_safe[:root], path: [*@n1_safe[:path], name], parent: self if child
      end
    end
    alias_method_chain name, :n1_safe
  end

  def has_many name, *args
    super
    n1_safe_define_association name, multiple: true
  end
  def has_one name, *args
    super
    n1_safe_define_association name
  end
  def belongs_to name, *args
    super
    n1_safe_define_association name
  end
end
