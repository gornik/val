defmodule Val do
  import Val.Combinators

  @type success :: {:ok, any}

  @type error :: :error

  @type validator :: (any -> success | error)

  @spec validate(validator, any) :: success | error
  def validate(validator, value) when is_validator(validator), do: validator.(value)

  @spec valid?(validator, any) :: boolean
  def valid?(validator, value) when is_function(validator, 1) do
    case validate(validator, value) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @doc """
  ## Examples
      iex> atom() |> required() |> valid?(:a)
      true
      iex> atom() |> required() |> valid?(nil)
      false
  """
  @spec required(validator) :: validator
  def required(validator), do: is_not_nil() |> and_then(validator)

  @doc """
  ## Examples
      iex> equals(:a) |> optional() |> valid?(:a)
      true
      iex> equals(:a) |> optional() |> valid?(:b)
      false
      iex> equals(:a) |> optional() |> valid?(nil)
      true
  """
  @spec optional(validator) :: validator
  def optional(validator), do: is_nil() |> or_else(validator)

  @doc """
  ## Examples
      iex> equals(:a) |> default(0) |> validate(:a)
      {:ok, :a}
      iex> equals(:a) |> default(0) |> validate(nil)
      {:ok, 0}
  """
  @spec default(validator, any) :: validator
  def default(validator, default) do
    is_nil()
    |> and_then(fn nil -> pass(default) end)
    |> or_else(validator)
  end

  @doc """
  ## Examples
      iex> equals(:a) |> valid?(:a)
      true
      iex> equals(:a) |> valid?(:b)
      false
  """
  @spec equals(any) :: validator
  def equals(constant), do: predicate(fn value -> value == constant end)

  @doc """
  ## Examples
      iex> not_equals(:a) |> valid?(:a)
      false
      iex> not_equals(:a) |> valid?(:b)
      true
  """
  @spec not_equals(any) :: validator
  def not_equals(constant), do: equals(constant) |> invert()

  @doc """
  ## Examples
      iex> one_of([:a, :b]) |> valid?(:a)
      true
      iex> one_of([:a, :b]) |> valid?(:b)
      true
      iex> one_of([:a, :b]) |> valid?(:c)
      false
  """
  @spec one_of([...]) :: validator
  def one_of([_ | _] = list) do
    list
    |> Enum.map(&equals/1)
    |> any()
  end

  @doc """
  ## Examples
      iex> is_nil() |> valid?(nil)
      true
      iex> is_nil() |> valid?(:a)
      false
  """
  @spec is_nil :: validator
  def is_nil, do: equals(nil)

  @doc """
  ## Examples
      iex> is_not_nil() |> valid?(nil)
      false
      iex> is_not_nil() |> valid?(:a)
      true
  """
  @spec is_not_nil :: validator
  def is_not_nil, do: not_equals(nil)

  @doc """
  ## Examples
      iex> boolean() |> valid?(true)
      true
      iex> boolean() |> valid?(false)
      true
      iex> boolean() |> valid?(:a)
      false
  """
  @spec boolean :: validator
  def boolean, do: predicate(&is_boolean/1)

  @doc """
  ## Examples
      iex> atom() |> valid?(:a)
      true
      iex> atom() |> valid?(nil)
      true
      iex> atom() |> valid?("a")
      false
  """
  @spec atom :: validator
  def atom, do: predicate(&is_atom/1)

  @doc """
  ## Examples
      iex> integer() |> valid?(1)
      true
      iex> integer() |> valid?(:a)
      false
      iex> integer() |> valid?(1.0)
      false
  """
  @spec integer :: validator
  def integer, do: predicate(&is_integer/1)

  @doc """
  ## Examples
      iex> float() |> valid?(1.0)
      true
      iex> float() |> valid?(:a)
      false
      iex> float() |> valid?(1)
      false
  """
  @spec float :: validator
  def float, do: predicate(&is_float/1)

  @doc """
  ## Examples
      iex> number() |> valid?(1)
      true
      iex> number() |> valid?(1.0)
      true
      iex> number() |> valid?(:a)
      false
  """
  @spec number :: validator
  def number, do: predicate(&is_number/1)

  @doc """
  ## Examples
      iex> less_than(2) |> valid?(1)
      true
      iex> less_than(2) |> valid?(3)
      false
      iex> less_than(2) |> valid?(2)
      false
      iex> less_than(:b) |> valid?(:a)
      true
  """
  @spec less_than(any) :: validator
  def less_than(constant), do: predicate(fn value -> value < constant end)

  @doc """
  ## Examples
      iex> less_or_equal(2) |> valid?(1)
      true
      iex> less_or_equal(2) |> valid?(3)
      false
      iex> less_or_equal(2) |> valid?(2)
      true
      iex> less_or_equal(:b) |> valid?(:a)
      true
  """
  @spec less_or_equal(any) :: validator
  def less_or_equal(constant), do: less_than(constant) |> or_else(equals(constant))

  @doc """
  ## Examples
      iex> greater_than(2) |> valid?(3)
      true
      iex> greater_than(2) |> valid?(1)
      false
      iex> greater_than(2) |> valid?(2)
      false
      iex> greater_than(:a) |> valid?(:b)
      true
  """
  @spec greater_than(any) :: validator
  def greater_than(constant), do: predicate(fn value -> value > constant end)

  @doc """
  ## Examples
      iex> greater_or_equal(2) |> valid?(3)
      true
      iex> greater_or_equal(2) |> valid?(1)
      false
      iex> greater_or_equal(2) |> valid?(2)
      true
      iex> greater_or_equal(:a) |> valid?(:b)
      true
  """
  @spec greater_or_equal(any) :: validator
  def greater_or_equal(constant), do: greater_than(constant) |> or_else(equals(constant))

  @doc """
  ## Examples
      iex> between(0, 2) |> valid?(1)
      true
      iex> between(0, 2) |> valid?(2)
      true
      iex> between(0, 2) |> valid?(3)
      false
      iex> between(:a, :z) |> valid?(:c)
      true
  """
  @spec between(any, any) :: validator
  def between(min, max), do: greater_or_equal(min) |> and_then(less_or_equal(max))

  @doc """
  ## Examples
      iex> positive() |> valid?(1)
      true
      iex> positive() |> valid?(-1)
      false
      iex> positive() |> valid?(0)
      false
  """
  @spec positive :: validator
  def positive, do: greater_than(0)

  @doc """
  ## Examples
      iex> negative() |> valid?(-1)
      true
      iex> negative() |> valid?(1)
      false
      iex> negative() |> valid?(0)
      false
  """
  @spec negative :: validator
  def negative, do: less_than(0)

  @doc """
  ## Examples
      iex> non_negative() |> valid?(1)
      true
      iex> non_negative() |> valid?(-1)
      false
      iex> non_negative() |> valid?(0)
      true
  """
  @spec non_negative :: validator
  def non_negative, do: negative() |> invert()

  @doc """
  ## Examples
      iex> non_positive() |> valid?(-1)
      true
      iex> non_positive() |> valid?(1)
      false
      iex> non_positive() |> valid?(0)
      true
  """
  @spec non_positive :: validator
  def non_positive, do: positive() |> invert()

  @doc """
  ## Examples
      iex> string() |> valid?("a")
      true
      iex> string() |> valid?(:a)
      false
  """
  @spec string :: validator
  def string, do: predicate(&is_binary/1)

  @doc """
  ## Examples
      iex> min_size(3) |> valid?("abc")
      true
      iex> min_size(3) |> valid?("abcd")
      true
      iex> min_size(3) |> valid?("a")
      false
      iex> min_size(3) |> valid?([:a, :b, :c])
      true
      iex> min_size(3) |> valid?([:a, :b, :c, :d])
      true
      iex> min_size(3) |> valid?([:a])
      false
  """
  @spec min_size(non_neg_integer) :: validator
  def min_size(min) do
    predicate(fn
      s when is_binary(s) -> String.length(s) >= min
      v -> Enum.count(v) >= min
    end)
  end

  @doc """
  ## Examples
      iex> max_size(3) |> valid?("a")
      true
      iex> max_size(3) |> valid?("abc")
      true
      iex> max_size(3) |> valid?("abcd")
      false
      iex> max_size(3) |> valid?([:a])
      true
      iex> max_size(3) |> valid?([:a, :b, :c])
      true
      iex> max_size(3) |> valid?([:a, :b, :c, :d])
      false
  """
  @spec max_size(non_neg_integer) :: validator
  def max_size(max) do
    predicate(fn
      s when is_binary(s) -> String.length(s) <= max
      v -> Enum.count(v) <= max
    end)
  end

  @doc """
  ## Examples
      iex> non_empty() |> valid?("a")
      true
      iex> non_empty() |> valid?("")
      false
      iex> non_empty() |> valid?([:a])
      true
      iex> non_empty() |> valid?([])
      false
  """
  @spec non_empty :: validator
  def non_empty, do: min_size(1)

  @doc """
  ## Examples
      iex> size_between(1, 3) |> valid?("a")
      true
      iex> size_between(1, 3) |> valid?("abc")
      true
      iex> size_between(1, 3) |> valid?("")
      false
      iex> size_between(1, 3) |> valid?("abcd")
      false
      iex> size_between(1, 3) |> valid?([:a])
      true
      iex> size_between(1, 3) |> valid?([:a, :b, :c])
      true
      iex> size_between(1, 3) |> valid?([])
      false
      iex> size_between(1, 3) |> valid?([:a, :b, :c, :d])
      false
  """
  @spec size_between(non_neg_integer, non_neg_integer) :: validator
  def size_between(min, max), do: min_size(min) |> and_then(max_size(max))
end
