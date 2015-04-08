class N1Safe::Preloader
  def initialize bases
    @bases = bases
    @cache = {}
    @cache[[]] = bases
    @count_cache = {}
  end

  def self.preloader
    @preloader ||= ActiveRecord::Associations::Preloader.new
  end

  def count model, path, name
    cache = @count_cache[[path, name]]
    return cache[[model.class, model.id]] if cache
    return model.send(name).size if @cache[[*path, name]]
    cache = {}
    all_siblings = @cache[path]
    all_siblings.group_by(&:class).each do |klass, siblings|
      reflection = klass.reflections[name]
      next if reflection.belongs_to?
      next unless reflection.collection?
      next if reflection.through_reflection
      key = reflection.active_record_primary_key
      relation = reflection.klass.where reflection.foreign_key => siblings.map{|m|m.send key}
      relation = relation.where reflection.type => klass.name if reflection.type
      relation = relation.instance_exec &reflection.scope if reflection.scope
      counts = relation.group(reflection.foreign_key).count
      siblings.each do |m|
        cache[[klass, m.id]] = counts[m.send key] || 0
      end
    end
    @count_cache[[path, name]] = cache
    cache[[model.class, model.id]]
  end

  def preload path
    return if @cache[path]
    *parent_path, name = path
    preload parent_path
    parents = @cache[parent_path]
    childs = {}
    Preloader.preloader.preload parents, name
    parents.map{|parent|
      child = parent.send(name)
      child = child.to_a if ActiveRecord::Relation === child
      childs[[parent.class, parent.id]] = child if child
    }
    @cache[path] = childs.values.flatten
  end
end
