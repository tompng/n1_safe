module N1Safe::Methods
  def n1_safe
    n1_safe_set
  end

  def n1_safe?
    !!@n1_safe
  end

  def without_n1_safe
    backup = @n1_safe
    @n1_safe = nil
    yield backup
    @n1_safe = backup
  end
end
