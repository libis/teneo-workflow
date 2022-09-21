# frozen_string_literal: true

require_relative "lib/teneo/workflow/version"

Gem::Specification.new do |spec|
  spec.name = "teneo-workflow"
  spec.version = Teneo::Workflow::VERSION
  spec.authors = ["Kris Dekeyser"]
  spec.email = ["kris@dva.be"]

  spec.summary = "Workflow infrastructure for Teneo."
  spec.description = "Workflow base implementation for the Teneo ingester."
  spec.homepage = "https://github.com/LIBIS/teneo-workflow"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "dry-configurable", "~> 0.0"
  spec.add_runtime_dependency "teneo-extensions", "~> 0.0"
  spec.add_runtime_dependency "teneo-parameter", "~> 0.0"
  spec.add_runtime_dependency "teneo-logger", "~> 1.0"
  spec.add_runtime_dependency "ruby-enum"
end
