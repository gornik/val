defmodule Val.Combinators do
  @typep success :: Val.success()
  @typep error :: Val.error()
  @typep validator :: Val.validator()

  defguard is_validator(fun) when is_function(fun, 1)

  @doc """
  ## Examples
      iex> pass(:a)
      {:ok, :a}
  """
  @spec pass(any) :: success
  def pass(value), do: {:ok, value}

  @doc """
  ## Examples
      iex> fail()
      :error
  """
  @spec fail :: error
  def fail, do: :error

  @doc """
  ## Examples
      iex> success() |> valid?(:a)
      true
  """
  @spec success :: validator
  def success, do: &pass/1

  @doc """
  ## Examples
      iex> failure() |> valid?(:a)
      false
  """
  @spec failure :: validator
  def failure, do: fn _ -> fail() end

  @doc """
  ## Examples
      iex> return(:b) |> validate(:a)
      {:ok, :b}
  """
  @spec return(any) :: validator
  def return(constant), do: fn _ -> pass(constant) end

  @doc """
  ## Examples
      iex> predicate(fn s -> String.starts_with?(s, "a") end) |> valid?("abc")
      true
      iex> predicate(fn s -> String.starts_with?(s, "a") end) |> valid?("bcd")
      false
  """
  @spec predicate((any -> as_boolean(any))) :: validator
  def predicate(fun) when is_function(fun, 1) do
    fn value ->
      if fun.(value), do: pass(value), else: fail()
    end
  end

  @doc """
  ## Examples
      iex> map(fn x -> x * 2 end) |> validate(3)
      {:ok, 6}
      iex> map(&String.downcase/1) |> validate("ABC")
      {:ok, "abc"}
  """
  @spec map((any -> any)) :: validator
  def map(fun) when is_function(fun, 1) do
    fn value ->
      value |> fun.() |> pass()
    end
  end

  @doc """
  ## Examples
      iex> try_map(&String.to_integer/1) |> validate("1")
      {:ok, 1}
      iex> try_map(&String.to_integer/1) |> validate("x")
      :error
  """
  @spec try_map((any -> any | no_return)) :: validator
  def try_map(fun) when is_function(fun, 1) do
    fn value ->
      try do
        map(fun).(value)
      rescue
        _ -> fail()
      end
    end
  end

  @doc """
  ## Examples
      iex> equals(:a) |> invert() |> valid?(:a)
      false
      iex> equals(:a) |> invert() |> valid?(:b)
      true
  """
  @spec invert(validator) :: validator
  def invert(validator) do
    fn value ->
      if Val.valid?(validator, value), do: fail(), else: pass(value)
    end
  end

  @doc """
  ## Examples
      iex> integer() |> and_then(positive()) |> valid?(1)
      true
      iex> integer() |> and_then(positive()) |> valid?(-1)
      false
      iex> integer() |> and_then(positive()) |> valid?(1.0)
      false
      iex> and_then(success(), success()) |> valid?(:a)
      true
      iex> and_then(failure(), success()) |> valid?(:a)
      false
      iex> and_then(success(), failure()) |> valid?(:a)
      false
      iex> and_then(failure(), failure()) |> valid?(:a)
      false
  """
  @spec and_then(validator, validator) :: validator
  def and_then(left, right) when is_validator(left) and is_validator(right) do
    fn value ->
      case left.(value) do
        {:ok, result} -> right.(result)
        :error -> :error
      end
    end
  end

  @doc """
  ## Examples
      iex> integer() |> or_else(string()) |> valid?(1)
      true
      iex> integer() |> or_else(string()) |> valid?("a")
      true
      iex> integer() |> or_else(string()) |> valid?(:a)
      false
      iex> or_else(success(), success()) |> valid?(:a)
      true
      iex> or_else(failure(), success()) |> valid?(:a)
      true
      iex> or_else(success(), failure()) |> valid?(:a)
      true
      iex> or_else(failure(), failure()) |> valid?(:a)
      false
  """
  @spec or_else(validator, validator) :: validator
  def or_else(left, right) when is_validator(left) and is_validator(right) do
    fn value ->
      case left.(value) do
        {:ok, result} -> {:ok, result}
        :error -> right.(value)
      end
    end
  end

  @doc """
  ## Examples
      iex> any([success()]) |> valid?(:a)
      true
      iex> any([failure()]) |> valid?(:a)
      false
      iex> any([success(), success()]) |> valid?(:a)
      true
      iex> any([failure(), success()]) |> valid?(:a)
      true
      iex> any([success(), failure()]) |> valid?(:a)
      true
      iex> any([failure(), failure()]) |> valid?(:a)
      false
      iex> any([success(), success(), success()]) |> valid?(:a)
      true
      iex> any([success(), failure(), success()]) |> valid?(:a)
      true
      iex> any([failure(), failure(), failure()]) |> valid?(:a)
      false
  """
  @spec any([validator, ...]) :: validator
  def any([validator | validators]) do
    Enum.reduce(validators, validator, fn v, acc -> or_else(acc, v) end)
  end

  @doc """
  ## Examples
      iex> all([success()]) |> valid?(:a)
      true
      iex> all([failure()]) |> valid?(:a)
      false
      iex> all([success(), success()]) |> valid?(:a)
      true
      iex> all([failure(), success()]) |> valid?(:a)
      false
      iex> all([success(), failure()]) |> valid?(:a)
      false
      iex> all([failure(), failure()]) |> valid?(:a)
      false
      iex> all([success(), success(), success()]) |> valid?(:a)
      true
      iex> all([success(), failure(), success()]) |> valid?(:a)
      false
  """
  @spec all([validator, ...]) :: validator
  def all([validator | validators]) do
    Enum.reduce(validators, validator, fn v, acc -> and_then(acc, v) end)
  end
end
