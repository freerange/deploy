# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{freerange_deploy}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["James Adam"]
  s.date = %q{2010-04-01}
  s.email = %q{james.adam@gofreerange.com}
  s.extra_rdoc_files = [
    "README"
  ]
  s.files = [
    "freerange_deploy.gemspec",
    "Rakefile",
    "README",
    "lib/freerange",
    "lib/freerange/deploy.rb"
  ]
  s.homepage = %q{http://gofreerange.com}
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Enables simple git-based deployments to freerange-compatible hosts}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<git-deploy>, ["~> 0.3.0"])
    else
      s.add_dependency(%q<git-deploy>, ["~> 0.3.0"])
    end
  else
    s.add_dependency(%q<git-deploy>, ["~> 0.3.0"])
  end
end
