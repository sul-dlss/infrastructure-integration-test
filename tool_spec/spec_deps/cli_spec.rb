# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# The bin/spec_deps commands, driven through SpecDeps::CLI with a recording runner.
RSpec.describe SpecDeps::CLI do
  let(:register) { 'spec/features/registration/register_spec.rb' }
  let(:review) { 'spec/features/verify/review_spec.rb' }
  let(:files) do
    {
      register => <<~RUBY,
        RSpec.describe 'Register', type: :registration do
          it { save_test_data(spec_name: 'object', data: {}) }
        end
      RUBY
      review => <<~RUBY
        RSpec.describe 'Review', type: :verify do
          let(:object) { load_test_data(spec_name: 'object') }
        end
      RUBY
    }
  end
  let(:root) { build_tree(files) }

  describe 'prereqs SPEC' do
    it 'prints only the prerequisites on stdout, and the reasons on stderr' do
      result = run_cli(root, 'prereqs', review)

      expect(result[:status]).to eq 0
      expect(result[:out]).to eq "#{register}\n"
      expect(result[:err]).to include("target: #{review} — needs registration/register_spec.rb (data `object`)")
    end

    it 'accepts paths relative to the repo root from any working directory' do
      expect(run_cli(root, 'prereqs', review)[:out]).to eq run_cli(root, 'prereqs', File.join(root, review))[:out]
    end

    it 'flags loads that no spec writes' do
      result = run_cli(build_tree(review => files[review]), 'prereqs', review)

      expect(result[:err]).to include('MISSING: no spec writes `object`')
    end
  end

  describe 'run SPEC' do
    it 'runs the prerequisites and the spec in one bin/rspec call, passing on args after --' do
      result = run_cli(root, 'run', review, '--', '--dry-run')

      expect(result[:runs]).to eq [[[File.join(root, 'bin', 'rspec'), register, review, '--dry-run'], root]]
    end

    it 'suggests fresh data when a not-replayable spec would run and a data file exists' do
      root = build_tree(files.merge('spec/spec_dependencies.yml' => "not_replayable:\n  #{review}: needs a fresh object\n",
                                    'tmp/2026-01-01_data.yml' => "object: {}\n"))

      expect(run_cli(root, 'run', review)[:err]).to include('note: tmp/2026-01-01_data.yml exist')
    end
  end

  describe '--failures' do
    it 'lists and runs the failed examples plus their prerequisites' do
      root = build_tree(files.merge('spec/examples.txt' => <<~TEXT))
        example_id | status | run_time |
        ---------- | ------ | -------- |
        ./#{review}[1:1] | failed | 1 second |
      TEXT

      expect(run_cli(root, 'prereqs', '--failures')[:out]).to eq "#{register}\n./#{review}[1:1]\n"
      expect(run_cli(root, 'run', '--failures')[:runs].first.first.drop(1)).to eq [register, "./#{review}[1:1]"]
    end

    it 'runs nothing when nothing failed' do
      root = build_tree(files.merge('spec/examples.txt' => "example_id | status |\n--- | --- |\n./#{review}[1:1] | passed |\n"))
      result = run_cli(root, 'run', '--failures')

      expect(result).to include(status: 0, runs: [])
      expect(result[:err]).to include('no failures recorded')
    end
  end

  describe 'usage errors' do
    it 'exits 1 with a message' do
      expect(run_cli(root, 'prereqs')).to include(status: 1, err: %r{usage: bin/spec_deps prereqs})
      expect(run_cli(root, 'run', '--failures', review)).to include(status: 1, err: /usage:/)
      expect(run_cli(root, 'prereqs', 'spec/features/nope_spec.rb')).to include(status: 1, err: /not a spec file/)
      expect(run_cli(root, 'bogus')).to include(status: 1, err: /unknown command 'bogus'/)
    end
  end

  describe '--write and --check' do
    it 'passes right after writing, and fails once the doc is edited' do
      expect(run_cli(root, '--write')[:status]).to eq 0
      expect(run_cli(root, '--check')).to include(status: 0, out: /is up to date/)

      File.write(File.join(root, 'spec_dependencies.md'), 'edited by hand', mode: 'a')

      expect(run_cli(root, '--check')).to include(status: 1, err: /is out of date/)
    end
  end

  it 'works end to end through bin/spec_deps, with SPEC_DEPS_ROOT pointing at the tree' do
    script = File.expand_path('../../bin/spec_deps', __dir__)
    out, _err, status = Open3.capture3({ 'SPEC_DEPS_ROOT' => root }, RbConfig.ruby, script, 'prereqs', review)

    expect(status).to be_success
    expect(out).to eq "#{register}\n"
  end
end
