# frozen_string_literal: true

# How SpecDeps reads data keys, gates and types out of spec code. Collector does the reading;
# these tests check its results through Graph, which resolves them per spec.
RSpec.describe SpecDeps::Collector do
  let(:writer) { 'spec/features/registration/writer_spec.rb' }
  let(:reader) { 'spec/features/accessioning/reader_spec.rb' }

  it 'reads string literal keys from save_test_data and load_test_data' do
    graph = graph_for(
      writer => <<~RUBY,
        RSpec.describe 'Writer', type: :registration do
          it { save_test_data(spec_name: 'apo_creation', data: {}) }
        end
      RUBY
      reader => <<~RUBY
        RSpec.describe 'Reader', type: :accessioning do
          let(:apo) { load_test_data(spec_name: 'apo_creation') }
        end
      RUBY
    )

    expect(graph.saves(writer).map(&:key)).to eq ['apo_creation']
    expect(graph.loads(reader).map(&:key)).to eq ['apo_creation']
    expect(graph.warnings).to be_empty
  end

  it 'turns interpolated keys into * patterns that match each other' do
    graph = graph_for(
      writer => <<~RUBY,
        RSpec.describe 'Writer', type: :registration do
          2.times do |i|
            it { save_test_data(spec_name: "constituent_\#{i}", data: {}) }
          end
        end
      RUBY
      reader => <<~RUBY
        RSpec.describe 'Reader', type: :accessioning do
          it { 2.times { |i| load_test_data(spec_name: "constituent_\#{i}") } }
        end
      RUBY
    )

    expect(graph.saves(writer).map(&:key)).to eq ['constituent_*']
    expect(graph.direct_prereqs(reader)).to eq [[writer, 'data `constituent_*`']]
  end

  describe 'shared examples' do
    let(:shared_example) do
      <<~RUBY
        RSpec.shared_examples 'an object registration' do
          let(:test_collection) { load_test_data(spec_name: 'collection_registration') }
          let(:save_job_id) { false }

          it 'registers' do
            save_test_data(spec_name:, data: {})
            save_test_data(spec_name: 'job_ids', data: {}) if save_job_id
          end
        end
      RUBY
    end

    it "resolves the `spec_name:` shorthand from each it_behaves_like block's let" do
      graph = graph_for(
        'spec/support/shared_examples/register.rb' => shared_example,
        writer => <<~RUBY
          RSpec.describe 'Register', type: :registration do
            it_behaves_like 'an object registration' do
              let(:spec_name) { 'item_one' }
            end
            it_behaves_like 'an object registration' do
              let(:spec_name) { 'item_two' }
            end
          end
        RUBY
      )

      expect(graph.saves(writer).map(&:key)).to eq %w[item_one item_two]
      expect(graph.saves(writer).map(&:via).uniq).to eq ['an object registration']
    end

    it "attributes the shared example's own loads to the spec that uses it" do
      graph = graph_for(
        'spec/support/shared_examples/register.rb' => shared_example,
        writer => <<~RUBY
          RSpec.describe 'Register', type: :registration do
            it_behaves_like 'an object registration' do
              let(:spec_name) { 'item_one' }
            end
          end
        RUBY
      )

      expect(graph.loads(writer).map(&:key)).to eq ['collection_registration']
    end

    it "skips a save guarded by a let that is false by default, and keeps it when the block's let overrides it" do
      graph = graph_for(
        'spec/support/shared_examples/register.rb' => shared_example,
        writer => <<~RUBY,
          RSpec.describe 'Default', type: :registration do
            it_behaves_like 'an object registration' do
              let(:spec_name) { 'item_one' }
            end
          end
        RUBY
        reader => <<~RUBY
          RSpec.describe 'Override', type: :accessioning do
            it_behaves_like 'an object registration' do
              let(:spec_name) { 'item_two' }
              let(:save_job_id) { true }
            end
          end
        RUBY
      )

      expect(graph.saves(writer).map(&:key)).not_to include('job_ids')
      expect(graph.saves(reader).map(&:key)).to include('job_ids')
      expect(graph.saves(reader).find { |ref| ref.key == 'job_ids' }.condition).to be_nil
    end

    it 'warns about a shared example it does not know' do
      graph = graph_for(writer => <<~RUBY)
        RSpec.describe 'Writer', type: :registration do
          it_behaves_like 'something defined elsewhere'
        end
      RUBY

      expect(graph.warnings).to eq ["#{writer}:2: unknown shared example 'something defined elsewhere'"]
    end
  end

  it "keeps a save whose condition can't be evaluated statically, and records the condition" do
    graph = graph_for(writer => <<~RUBY)
      RSpec.describe 'Writer', type: :registration do
        it { save_test_data(spec_name: 'maybe', data: {}) if Settings.feature.enabled }
      end
    RUBY

    expect(graph.saves(writer).map { |ref| [ref.key, ref.condition] }).to eq [['maybe', 'Settings.feature.enabled']]
  end

  it 'records if: gates from describe and from an enclosing context' do
    graph = graph_for(writer => <<~RUBY)
      RSpec.describe 'Writer', if: Settings.ocr.enabled, type: :registration do
        context 'on stage', if: $sdr_env == 'stage' do
          it { save_test_data(spec_name: 'stage_only', data: {}) }
        end
      end
    RUBY

    expect(graph.spec(writer).gates).to eq ['if: Settings.ocr.enabled']
    expect(graph.saves(writer).first.gates).to eq ['if: Settings.ocr.enabled', "if: $sdr_env == 'stage'"]
  end

  it "reads each spec's type, and warns about specs without one" do
    graph = graph_for(
      writer => "RSpec.describe 'Writer', type: :registration do\nend\n",
      'spec/features/untyped_spec.rb' => "RSpec.describe 'Untyped' do\nend\n"
    )

    expect(graph.spec(writer).type).to eq :registration
    expect(graph.warnings).to eq ['spec/features/untyped_spec.rb: no `type:` metadata, so the global ordering will not run it']
  end

  it 'warns about keys it cannot resolve instead of silently dropping them' do
    graph = graph_for(reader => <<~RUBY)
      RSpec.describe 'Reader', type: :accessioning do
        let(:a) { load_test_data(spec_name: names[:apo]) }
        let(:b) { load_test_data(spec_name: undefined_let) }
      end
    RUBY

    expect(graph.loads(reader)).to be_empty
    expect(graph.warnings).to eq [
      "#{reader}:2: could not resolve data key names[:apo]",
      "#{reader}:3: could not resolve data key undefined_let"
    ]
  end
end
