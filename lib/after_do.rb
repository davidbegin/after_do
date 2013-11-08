class NonExistingMethodError < StandardError ; end

module AfterDo
  ALIAS_PREFIX = '__after_do_orig_'

  def after(*methods, &block)
    # Yes I know omg class variables, but I want callbacks to work across
    # subclasses. Suggestions welcome. See 9926bc859930a for more
    @@_after_do_callbacks ||= Hash.new([])
    methods.flatten! #in case someone used an Array
    if methods.empty?
      raise ArgumentError, 'after takes at least one method name!'
    end
    methods.each do |method|
      if _after_do_method_already_renamed?(method)
        _after_do_make_after_do_version_of_method(method)
      end
      @@_after_do_callbacks[method] << block
    end
  end

  def remove_all_callbacks
    @@_after_do_callbacks = Hash.new([]) if @@_after_do_callbacks
  end

  private
  def _after_do_make_after_do_version_of_method(method)
    _after_do_raise_no_method_error(method) unless self.method_defined? method
    @@_after_do_callbacks[method] = []
    alias_name = _after_do_aliased_name method
    _after_do_rename_old_method(method, alias_name)
    _after_do_redefine_method_with_callback(method, alias_name)
  end

  def _after_do_raise_no_method_error method
    raise NonExistingMethodError, "There is no method #{method} on #{self} to attach a block to with AfterDo"
  end

  def _after_do_aliased_name(symbol)
    (ALIAS_PREFIX + symbol.to_s).to_sym
  end

  def _after_do_rename_old_method(old_name, new_name)
    class_eval do
      alias_method new_name, old_name
      private new_name
    end
  end

  def _after_do_redefine_method_with_callback(method, alias_name)
    class_eval do
      define_method method do |*args|
        return_value = send(alias_name, *args)
        @@_after_do_callbacks[method].each do |block|
          block.call *args, self
        end
        return_value
      end
    end
  end

  def _after_do_method_already_renamed?(method)
    !private_method_defined? _after_do_aliased_name(method)
  end
end