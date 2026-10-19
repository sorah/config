# frozen_string_literal: true

# Required from config/boot.rb on Lambda. Copies SSM parameters into ENV before Rails reads it:
# SSM_SECRET__FOO=<parameter arn> sets ENV['FOO'].
require 'aws-sdk-ssm'
ssm = Aws::SSM::Client.new
r = /^SSM_SECRET__/
params = ENV.keys.grep(r).map do |k|
  [ENV[k], k.sub(r, '')]
end.to_h
# GetParameters takes at most 10 names.
params.keys.each_slice(10) do |names|
  ssm.get_parameters(
    names:,
    with_decryption: true,
  ).parameters.each do |pa|
    ENV[params.fetch(pa.arn)] = pa.value
  end
end
