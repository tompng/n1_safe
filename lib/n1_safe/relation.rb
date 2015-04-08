class N1Safe::Relation < BasicObject
  def initialize root, collection, path, parent
    @root = root
    @collection = collection
    @path = path
    @parent = parent
  end

  ::Array.instance_methods.each do |name|
    define_method name do |*args, &block|
      @root.preload @path
      @collection.map{|model|
        ::N1Safe::Model.new @root, model, (@path||[])
      }.send(name, *args, &block)
    end
  end

  def size
    return @collection.size if @parent.nil?
    *parent_path, name = @path
    count = @root.count @parent, parent_path, name
    return count if count
    @root.preload @path
    @collection.size
  end

  def count
    size
  end

  def method_missing name, *args, &block
    @collection.send name, *args, &block
  end
end
