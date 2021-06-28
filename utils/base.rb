# frozen_string_literal: true

# base module
module Base
  def self.included(mod)
    methods = mod.methods(false)
    methods.each do |m|
      mod.singleton_class.send :alias_method, "new_#{m}", m
      mod.singleton_class.define_method(m) do |*args|
        puts "method=[#{m}], args=#{args}"
        mod.send "new_#{m}", *args
      end
    end
  end
end
