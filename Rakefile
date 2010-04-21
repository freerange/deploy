require "rubygems"
require "rake/gempackagetask"
require "rake/rdoctask"

path = File.expand_path("..", __FILE__)

task :default => :package do
  puts "Don't forget to write some tests!"
end

# This builds the actual gem. For details of what all these options
# mean, and other ones you can add, check the documentation here:
#
#   http://rubygems.org/read/chapter/20
#
spec = Gem::Specification.new do |s|

  # Change these as appropriate
  s.name               = "freerange_deploy"
  s.version            = "0.1.8"
  s.summary            = "Enables simple git-based deployments to freerange-compatible hosts"
  s.author             = "James Adam, Tom Ward, Kalvir Sandhu"
  s.email              = "lets@gofreerange.com"
  s.homepage           = "http://gofreerange.com"
  s.default_executable = %q{freerange-deploy}
  s.executables        = ["freerange-deploy"]
  
  s.has_rdoc          = true
  s.extra_rdoc_files  = %w(README)
  s.rdoc_options      = %w(--main README)

  # Add any extra files to include in the gem
  s.files             = `cd #{path} && git ls-files`.split("\n").sort
  s.require_paths     = ["lib"]

  # If you want to depend on other gems, add them here, along with any
  # relevant versions
  s.add_dependency("capistrano")
  s.add_dependency("capistrano-ext")
  s.add_dependency("thor")
  s.add_dependency("tinder")
  s.add_dependency("json")

  # If your tests use any gems, include them here
  # s.add_development_dependency("mocha") # for example
end

# This task actually builds the gem. We also regenerate a static
# .gemspec file, which is useful if something (i.e. GitHub) will
# be automatically building a gem for this project. If you're not
# using GitHub, edit as appropriate.
#
# To publish your gem online, install the 'gemcutter' gem; Read more 
# about that here: http://gemcutter.org/pages/gem_docs
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

# Stolen from jeweler
def prettyify_array(gemspec_ruby, array_name)
  gemspec_ruby.gsub(/s\.#{array_name.to_s} = \[.+?\]/) do |match|
    leadin, files = match[0..-2].split("[")
    leadin + "[\n    #{files.split(",").join(",\n   ")}\n  ]"
  end
end

task :gemspec do
  output = spec.to_ruby
  output = prettyify_array(output, :files)
  output = prettyify_array(output, :test_files)
  output = prettyify_array(output, :extra_rdoc_files)

  file = File.expand_path("../#{spec.name}.gemspec", __FILE__)
  File.open(file, "w") {|f| f << output }
end

task :package => :gemspec

# Generate documentation
Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.rdoc_files.include("README", "lib/**/*.rb")
  rd.rdoc_dir = "rdoc"
end

desc 'Clear out RDoc and generated packages'
task :clean => [:clobber_rdoc, :clobber_package] do
  rm "#{spec.name}.gemspec"
end
