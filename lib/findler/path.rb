require 'pathname'

class Findler
  class Path
    def self.clean(path)
      path = Pathname.new(path) unless path.is_a? Pathname
      path = path.expand_path unless path.absolute?
      path
    end

    def self.base(path)
      path.basename.to_s
    end

    def self.clean_array(array)
      array.map { |ea| clean(ea) }
    end

    def self.base_array(array)
      array.map { |ea| base(ea) }
    end

    def self.hidden?(path)
      base(path).start_with?('.')
    end
  end
end
