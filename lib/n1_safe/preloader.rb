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
      reflection = klass.reflections[name] || klass.reflections[name.to_s]
      next unless reflection
      next if reflection.belongs_to?
      next unless reflection.collection?
      next if reflection.through_reflection #through count not implemented
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
    parents = @cache[parent_path].select{|p|
      p.class.reflections[name]||p.class.reflections[name.to_s]
    }
    self.class.preloader.preload parents, name
    @cache[path] = parents.flat_map{|parent|
      child = parent.send(name)
      if ActiveRecord::Relation === child
        child.to_a
      else
        child
      end
    }.compact.uniq
  end
end
