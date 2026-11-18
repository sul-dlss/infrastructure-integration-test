# frozen_string_literal: true

# How SpecDeps reads the last run's failures and builds the bin/rspec arguments to retry them.
RSpec.describe SpecDeps::Failures do
  let(:register) { 'spec/features/registration/register_spec.rb' }
  let(:accession) { 'spec/features/accessioning/accession_spec.rb' }
  let(:review) { 'spec/features/verify/review_spec.rb' }

  # register -> accession -> review, by data.
  let(:files) do
    {
      register => <<~RUBY,
        RSpec.describe 'Register', type: :registration do
          it { save_test_data(spec_name: 'object', data: {}) }
        end
      RUBY
      accession => <<~RUBY,
        RSpec.describe 'Accession', type: :accessioning do
          let(:object) { load_test_data(spec_name: 'object') }
          it { save_test_data(spec_name: 'accessioned', data: {}) }
        end
      RUBY
      review => <<~RUBY
        RSpec.describe 'Review', type: :verify do
          let(:accessioned) { load_test_data(spec_name: 'accessioned') }
        end
      RUBY
    }
  end

  # The format RSpec writes to example_status_persistence_file_path.
  def status_file(rows)
    lines = rows.map { |id, status| "#{id.ljust(50)} | #{status.ljust(6)} | 1 second |" }
    "#{["#{'example_id'.ljust(50)} | status | run_time |", "#{'-' * 50} | ------ | -------- |", *lines].join("\n")}\n"
  end

  describe '.parse' do
    it 'returns the ids of failed examples only' do
      text = status_file([["./#{register}[1:1]", 'passed'], ["./#{review}[1:1]", 'failed'], ["./#{review}[1:2]", 'pending']])

      expect(described_class.parse(text)).to eq ["./#{review}[1:1]"]
    end
  end

  describe '.last' do
    it 'groups failed ids by spec, and skips specs that no longer exist with a warning' do
      gone = 'spec/features/verify/gone_spec.rb'
      rows = [["./#{review}[1:1]", 'failed'], ["./#{gone}[1:1]", 'failed']]
      graph = graph_for(files.merge('spec/examples.txt' => status_file(rows)))
      err = StringIO.new

      expect(described_class.last(graph, err:)).to eq(review => ["./#{review}[1:1]"])
      expect(err.string).to eq "warning: spec/examples.txt lists #{gone}, which is no longer a spec; skipping\n"
    end

    it 'raises when the status file does not exist yet' do
      graph = graph_for(files)

      expect { described_class.last(graph, err: StringIO.new) }.to raise_error(SpecDeps::Error, /examples.txt not found/)
    end

    it "raises when spec_helper doesn't configure a status file" do
      graph = graph_for(files.merge('spec/spec_helper.rb' => "order = %i[registration accessioning sdr verify preassembly]\n"))

      expect { described_class.last(graph, err: StringIO.new) }
        .to raise_error(SpecDeps::Error, /does not set example_status_persistence_file_path/)
    end
  end

  describe '.rspec_args' do
    it 'reruns failed examples by id, after their prerequisites as whole files' do
      graph = graph_for(files)

      expect(described_class.rspec_args(graph, review => ["./#{review}[1:1]", "./#{review}[1:3]"]))
        .to eq [register, accession, "./#{review}[1:1]", "./#{review}[1:3]"]
    end

    it 'runs a failed spec as a whole file when another failure depends on it' do
      graph = graph_for(files)
      failures = { accession => ["./#{accession}[1:1]"], review => ["./#{review}[1:1]"] }

      expect(described_class.rspec_args(graph, failures)).to eq [register, accession, "./#{review}[1:1]"]
    end
  end
end
