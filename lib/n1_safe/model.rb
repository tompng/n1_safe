class N1Safe::Model < BasicObject
  def initialize root, model, path
    @root = root
    @model = model
    @path = path
  end
  def method_missing name, *args, &block
    reflection = @model.class.reflections[name]
    if reflection.nil? || args.present? || block
      return @model.send(name, *args, &block)
    end
    if reflection.collection?
      childs = send name
      ::N1Safe::Relation.new @root, childs, [*@path, name], @model
    else
      @root.preload [*@path, name]
      child = send name
      Model.new @root, child, [*@path, name] if child
    end
  end
end
