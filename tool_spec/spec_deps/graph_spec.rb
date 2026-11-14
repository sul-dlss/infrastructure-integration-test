# frozen_string_literal: true

# How SpecDeps turns extracted keys into prerequisites and chains.
RSpec.describe SpecDeps::Graph do
  let(:apo) { 'spec/features/registration/01_apo_spec.rb' }
  let(:collection) { 'spec/features/registration/02_collection_spec.rb' }
  let(:accession) { 'spec/features/accessioning/accession_spec.rb' }
  let(:review) { 'spec/features/a_first_by_path/review_spec.rb' }

  # apo -> collection -> accession -> review, by data. `review` sorts first by path but is a verify spec.
  let(:files) do
    {
      apo => <<~RUBY,
        RSpec.describe 'APO', type: :registration do
          it { save_test_data(spec_name: 'apo', data: {}) }
        end
      RUBY
      collection => <<~RUBY,
        RSpec.describe 'Collection', type: :registration do
          let(:apo) { load_test_data(spec_name: 'apo') }
          it { save_test_data(spec_name: 'collection', data: {}) }
        end
      RUBY
      accession => <<~RUBY,
        RSpec.describe 'Accession', type: :accessioning do
          let(:collection) { load_test_data(spec_name: 'collection') }
          it { save_test_data(spec_name: 'accession', data: {}) }
        end
      RUBY
      review => <<~RUBY
        RSpec.describe 'Review', type: :verify do
          let(:accession) { load_test_data(spec_name: 'accession') }
        end
      RUBY
    }
  end

  it 'follows prerequisites transitively, in run order: by type, then by path' do
    graph = graph_for(files)

    expect(graph.chain([review])).to eq [apo, collection, accession]
    expect(graph.specs.map(&:path)).to eq [apo, collection, accession, review]
  end

  it 'leaves the targets themselves out of the chain' do
    graph = graph_for(files)

    expect(graph.chain([collection, review])).to eq [apo, accession]
  end

  it 'does not make a spec depend on itself when it rewrites a key it loads' do
    graph = graph_for(
      apo => <<~RUBY,
        RSpec.describe 'APO', type: :registration do
          it { save_test_data(spec_name: 'item', data: {}) }
        end
      RUBY
      accession => <<~RUBY
        RSpec.describe 'Accession', type: :accessioning do
          let(:item) { load_test_data(spec_name: 'item') }
          it { save_test_data(spec_name: 'item', data: item.merge(job_id: 1)) }
        end
      RUBY
    )

    expect(graph.direct_prereqs(accession)).to eq [[apo, 'data `item`']]
    expect(graph.readers('item', except: accession)).to be_empty
  end

  it 'finds no writers for a key nothing saves' do
    graph = graph_for(review => files[review])

    expect(graph.writers('accession', except: review)).to be_empty
    expect(graph.chain([review])).to be_empty
  end

  describe 'spec/spec_dependencies.yml' do
    it 'adds state dependencies as prerequisites of their own kind' do
      graph = graph_for(files.merge('spec/spec_dependencies.yml' => <<~YAML))
        state_dependencies:
          #{review}:
            - #{collection}
        not_replayable:
          #{review}: needs a fresh object
      YAML

      expect(graph.direct_prereqs(review)).to eq [[accession, 'data `accession`'], [collection, 'state']]
      expect(graph.not_replayable(review)).to eq 'needs a fresh object'
    end

    it 'raises if it names a spec that does not exist' do
      expect do
        graph_for(files.merge('spec/spec_dependencies.yml' => "not_replayable:\n  spec/features/gone_spec.rb: reason\n"))
      end.to raise_error(SpecDeps::Error, %r{names specs that don't exist: spec/features/gone_spec.rb})
    end
  end

  it "reports when spec_helper's type order no longer matches SpecDeps::TYPE_ORDER" do
    graph = graph_for(files.merge('spec/spec_helper.rb' => "order = %i[registration verify accessioning]\n"))

    expect(graph.type_order_problem).to match(%r{does not match spec/spec_helper.rb})
    expect(graph.warnings).to include(graph.type_order_problem)
  end
end
