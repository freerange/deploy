# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{freerange-deploy}
  s.version = "1.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Chris Roos, James Adam, Tom Ward, Kalvir Sandhu"]
  s.date = %q{2010-11-16}
  s.default_executable = %q{freerange-deploy}
  s.email = %q{lets@gofreerange.com}
  s.executables = ["freerange-deploy"]
  s.extra_rdoc_files = [
    "README"
  ]
  s.files = [
    ".gitignore",
    "README",
    "Rakefile",
    "bin/freerange-deploy",
    "freerange-deploy.gemspec",
    "lib/freerange/cli/deploy.rb",
    "lib/freerange/cli/templates/Capfile.erb",
    "lib/freerange/cli/templates/deploy.rb.erb",
    "lib/freerange/cli/templates/production.rb.erb",
    "lib/freerange/cli/templates/staging.rb.erb",
    "lib/freerange/deploy.rb",
    "lib/freerange/deploy/aws.rb",
    "lib/freerange/deploy/build.rb",
    "lib/freerange/log.rb",
    "lib/freerange/webhook.rb"
  ]
  s.homepage = %q{http://gofreerange.com}
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Enables simple git-based deployments to freerange-compatible hosts}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, [">= 0"])
      s.add_runtime_dependency(%q<capistrano-ext>, [">= 0"])
      s.add_runtime_dependency(%q<thor>, [">= 0"])
      s.add_runtime_dependency(%q<tinder>, ["= 1.4.1"])
      s.add_runtime_dependency(%q<right_aws>, ["= 2.0.0"])
      s.add_runtime_dependency(%q<json>, [">= 0"])
      s.add_runtime_dependency(%q<request-log-analyzer>, [">= 0"])
    else
      s.add_dependency(%q<capistrano>, [">= 0"])
      s.add_dependency(%q<capistrano-ext>, [">= 0"])
      s.add_dependency(%q<thor>, [">= 0"])
      s.add_dependency(%q<tinder>, ["= 1.4.1"])
      s.add_dependency(%q<right_aws>, ["= 2.0.0"])
      s.add_dependency(%q<json>, [">= 0"])
      s.add_dependency(%q<request-log-analyzer>, [">= 0"])
    end
  else
    s.add_dependency(%q<capistrano>, [">= 0"])
    s.add_dependency(%q<capistrano-ext>, [">= 0"])
    s.add_dependency(%q<thor>, [">= 0"])
    s.add_dependency(%q<tinder>, ["= 1.4.1"])
    s.add_dependency(%q<right_aws>, ["= 2.0.0"])
    s.add_dependency(%q<json>, [">= 0"])
    s.add_dependency(%q<request-log-analyzer>, [">= 0"])
  end
end
