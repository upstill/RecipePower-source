module DecoratorHelper
  # Ensure that an object (or a decorator on an object) is suitable for polymorphic operations
  def polymorphable object_or_decorator
    # Use the object in case we got a decorator
    object = object_or_decorator.is_a?(Draper::Decorator) ? object_or_decorator.object : object_or_decorator

    # Reduce the object to its base class for the use of polymorphic_path
    bc = object.class.base_class
    (bc == object.class) ? object : object.becomes(bc)
  end
end
