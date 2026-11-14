# frozen_string_literal: true

# The rendered dependency doc, compared with a golden copy in tool_spec/fixtures/sample_doc.md.
# After an intended change to the doc's format, regenerate the golden copy with
#   UPDATE_GOLDEN=1 bin/rspec -O tool_spec/.rspec tool_spec/spec_deps/doc_spec.rb
# and review its diff.
RSpec.describe SpecDeps::Doc do
  let(:golden) { File.expand_path('../fixtures/sample_doc.md', __dir__) }

  # A miniature of the real suite: registration, accessioning via a shared example, a gated
  # registration, a verify spec with a state dependency, plus a few things the doc should flag.
  let(:files) do
    {
      'spec/support/shared_examples/registration.rb' => <<~RUBY,
        RSpec.shared_examples 'an object registration' do
          let(:test_apo) { load_test_data(spec_name: 'apo_creation') }
          it { save_test_data(spec_name:, data: {}) }
        end
      RUBY
      'spec/support/shared_examples/preassembly.rb' => <<~RUBY,
        RSpec.shared_examples 'a preassembly job' do
          let(:test_data) { load_test_data(spec_name:) }
          let(:save_job_id) { false }
          it { save_test_data(spec_name:, data: {}) if save_job_id }
        end
      RUBY
      'spec/features/registration/01_apo_registration_spec.rb' => <<~RUBY,
        RSpec.describe 'APO', type: :registration do
          it { save_test_data(spec_name: 'apo_creation', data: {}) }
        end
      RUBY
      'spec/features/registration/02_register_objects_spec.rb' => <<~RUBY,
        RSpec.describe 'Register objects', type: :registration do
          it_behaves_like 'an object registration' do
            let(:spec_name) { 'image_accessioning' }
          end
          context 'on stage', if: $sdr_env == 'stage' do
            it_behaves_like 'an object registration' do
              let(:spec_name) { 'goobi_accessioning' }
            end
          end
          2.times do |i|
            it_behaves_like 'an object registration' do
              let(:spec_name) { "constituent_\#{i}" }
            end
          end
        end
      RUBY
      'spec/features/accessioning/image_accessioning_spec.rb' => <<~RUBY,
        RSpec.describe 'Image accessioning', type: :accessioning do
          it_behaves_like 'a preassembly job' do
            let(:spec_name) { 'image_accessioning' }
            let(:save_job_id) { true }
          end
        end
      RUBY
      'spec/features/accessioning/virtual_object_spec.rb' => <<~RUBY,
        RSpec.describe 'Virtual object', type: :accessioning do
          it { 2.times { |i| load_test_data(spec_name: "constituent_\#{i}") } }
        end
      RUBY
      'spec/features/sdr/standalone_spec.rb' => <<~RUBY,
        RSpec.describe 'Standalone', type: :sdr do
          it { save_test_data(spec_name: 'standalone', data: {}) }
        end
      RUBY
      'spec/features/verify/image_review_spec.rb' => <<~RUBY,
        RSpec.describe 'Image review', if: Settings.review.enabled, type: :verify do
          let(:test_data) { load_test_data(spec_name: 'image_accessioning') }
          let(:missing) { load_test_data(spec_name: 'never_saved') }
        end
      RUBY
      'spec/features/untyped_spec.rb' => "RSpec.describe 'Untyped' do\nend\n",
      'spec/spec_dependencies.yml' => <<~YAML
        state_dependencies:
          spec/features/verify/image_review_spec.rb:
            - spec/features/accessioning/image_accessioning_spec.rb
        not_replayable:
          spec/features/verify/image_review_spec.rb: needs a freshly accessioned object
      YAML
    }
  end

  it 'renders the sample tree as in the golden copy' do
    doc = described_class.new(graph_for(files)).to_s
    File.write(golden, doc) if ENV['UPDATE_GOLDEN']

    expect(doc).to eq File.read(golden)
  end
end
