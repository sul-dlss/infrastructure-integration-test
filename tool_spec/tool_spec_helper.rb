# frozen_string_literal: true

# Unit tests for the repo's own tooling (lib/), kept apart from the integration suite in spec/.
# Run with: bin/rspec -O tool_spec/.rspec
#
# Passing -O replaces the project .rspec, so spec/spec_helper.rb (browser, Settings, global ordering,
# example status persistence) is never loaded. Each test builds the small repo tree it needs in a
# temp dir; see TreeHelpers below and CODING_STANDARDS.md.

require 'fileutils'
require 'stringio'
require 'tmpdir'
require_relative '../lib/spec_deps'

# Builds throwaway repo trees for SpecDeps to analyze.
module TreeHelpers
  # The two lines SpecDeps reads from spec/spec_helper.rb: the type order and the status file path.
  SPEC_HELPER = <<~RUBY
    RSpec.configure do |config|
      config.example_status_persistence_file_path = 'spec/examples.txt'
      config.register_ordering(:global) do |examples|
        order = %i[registration accessioning sdr verify preassembly]
        examples.sort_by { |example| order.index(example.metadata[:type]) }
      end
    end
  RUBY

  # Writes `files` ({ relative path => content }) under a new temp dir, along with a default
  # spec/spec_helper.rb unless `files` provides one, and returns the dir. Removed after each test.
  def build_tree(files)
    root = Dir.mktmpdir('spec_deps')
    built_trees << root
    { 'spec/spec_helper.rb' => SPEC_HELPER }.merge(files).each do |path, content|
      FileUtils.mkdir_p(File.dirname(File.join(root, path)))
      File.write(File.join(root, path), content)
    end
    root
  end

  def graph_for(files) = SpecDeps::Graph.new(build_tree(files))

  def built_trees = (@built_trees ||= [])

  # Runs SpecDeps::CLI in-process. The runner records what would have been exec'd instead of running it.
  def run_cli(root, *argv)
    out = StringIO.new
    err = StringIO.new
    runs = []
    status = SpecDeps::CLI.new(root:, out:, err:, runner: ->(command, dir) { runs << [command, dir] }).call(argv)
    { status:, out: out.string, err: err.string, runs: }
  end
end

RSpec.configure do |config|
  config.include TreeHelpers
  config.after { built_trees.each { |root| FileUtils.remove_entry(root) } }
  config.disable_monkey_patching!
end
