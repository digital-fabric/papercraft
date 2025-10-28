# frozen_string_literal: true

require 'benchmark/ips'

pr = proc {}

Benchmark.ips do |x|
  x.report("call") { pr.call }
  x.report("i_eval") { instance_eval(&pr) }

  x.compare!(order: :baseline)
end
