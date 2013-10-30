class SignatureAnalyzer
  def initialize(params)
    @polynom_indexes = params[:polynom_indexes].dup.freeze
    @triggers = [0] * @polynom_indexes.size
  end

  def run(input)
    fail_if_not_array(input)
    [triggers] + input.map { |x| run_once(x) }
  end

  def run_once(x)
    fail "Input must be 0 or 1" unless (0..1).include? x
    prev_state = triggers
    @triggers.rotate!
    @triggers[-1] = prev_state
      .zip(@polynom_indexes)
      .map { |a, b| a & b }
      .reduce(:^) ^ x
    triggers
  end

  def reset
    @triggers.map! { 0 }
  end

  def triggers
    @triggers.dup
  end

  def output_chain_for(input)
    fail_if_not_array(input)
    reset
    run(input).map(&:first)
  end

  private

  def fail_if_not_array(input)
    fail "input must be an array" unless input.is_a? Array
  end
end

class SignatureAnalyzer2
  def initialize(params)
    @polynom_indexes = params[:polynom_indexes].dup.freeze
    @triggers = [0] * @polynom_indexes.size
  end

  def output_chain_for(input)
    output = []
    polynom_size = @polynom_indexes.size
    polynom = @polynom_indexes
      .map.with_index { |x, i| x > 0 ? polynom_size - i : nil }
      .compact
    register1, register2 = [0] * polynom_size, [0] * polynom_size
    for i in 0 ... input.size / 2
      new_val = input[2 * i]
      polynom.each { |pow| new_val ^= register1[pow - 1] }
      output << register1.last
      register1.pop
      register1.unshift(new_val)

      new_val = input[2 * i + 1]
      polynom.each { |pow| new_val ^= register2[pow - 1] }
      output << register2.last
      register2.pop
      register2.unshift(new_val)
    end
    output
  end
end

class Integer
  def invert
    self == 1 ? 0 : 1
  end
end

class SATester
  ONE_CHANNEL_TEST_SIZE = 8
  TWO_CHANNEL_TEST_SIZE = 16

  attr_reader :test

  def initialize(params)
    @sa = params[:sa]
    @sa2 = params[:sa2]
    @l = params[:l]
    @test = Array.new(@l) { rand(2) }
    @constant_single_test_part = @test.take(@l - ONE_CHANNEL_TEST_SIZE)
    @constant_double_test_part = @test.take(@l - TWO_CHANNEL_TEST_SIZE)
  end

  def errors(params)
    channels = params[:channels]
    errors = params[:count]
    error_tests = []
    sa = channels == 1 ? @sa : @sa2
    etalon = sa.output_chain_for(@test)
    noised_tests(errors: errors, channels: channels).each do |noised_test|
      if etalon == sa.output_chain_for(noised_test)
        error_tests << noised_test
      end
    end
    error_tests
  end

  private

  def noised_tests(params)
    errors = params[:errors]
    channels = params[:channels]
    fail 'errors must be in range 0..4' unless (0..4).include? errors
    mask_invert = proc { |i, x| i == 1 ? x.invert : x }
    constant_test_size = channels == 1 ? ONE_CHANNEL_TEST_SIZE : TWO_CHANNEL_TEST_SIZE
    constant_test_part = channels == 1 ? @constant_single_test_part : @constant_double_test_part
    tests = [0, 1] # rewrite this
      .repeated_permutation(constant_test_size)
      .select { |test| test.count(1) == errors }
      .map { |mask| mask.zip(@test.dup.drop(@l - constant_test_size)).map(&mask_invert) }
      .map { |test| constant_test_part + test }
  end
end

sa_polynom = [1, 0, 1, 0, 0, 1, 1, 0] # x8 + x6 + x3 + x2 + 1
sa = SignatureAnalyzer.new(polynom_indexes: sa_polynom)
sa2 = SignatureAnalyzer2.new(polynom_indexes: sa_polynom)
sa_tester = SATester.new(sa: sa, sa2: sa2, l: 40)
puts 'test:'
puts sa_tester.test.join
puts
(1..4).each do |errors|
  puts "errors: #{errors}"
  puts "one channel:"
  one_channel_errors = sa_tester.errors(count: errors, channels: 1)
  one_channel_errors.each { |test| puts test.join }
  puts "count: #{one_channel_errors.size}"
  puts "two channel:"
  two_channel_errors = sa_tester.errors(count: errors, channels: 2)
  two_channel_errors.each { |test| puts test.join }
  puts "count: #{two_channel_errors.size}"
  puts '-' * 80
end