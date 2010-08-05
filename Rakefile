require 'rake'
require 'rubygems'
require 'spec'
# require 'spec/autorun'
# require 'spec/interop/test'
require 'spec/rake/spectask'
# require 'rack/test'

namespace :spec do
  desc "Run specific spec (SPEC=/path/2/file)"
  Spec::Rake::SpecTask.new(:select) do |t|
    # t.libs << "lib"
    t.spec_files = [ENV["SPEC"]]
    t.spec_opts = %w(--color --format specdoc --require spec/spec_helper.rb)
  end
end

desc "Run Specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = Dir["spec/**/*_spec.rb"]
  t.spec_opts = %w(--color --format progress --loadby mtime --require spec/spec_helper.rb)
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.rcov = false
end

task :default => :spec
